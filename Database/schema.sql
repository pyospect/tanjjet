-- Tanjjet 데이터베이스 스키마
-- Supabase SQL Editor에서 실행하세요

-- 1. profiles 테이블: 사용자 프로필 정보
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nickname TEXT,
    couple_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. couples 테이블: 커플 연결 정보
CREATE TABLE IF NOT EXISTS public.couples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    user1_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user2_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. messages 테이블: 메시지 저장
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- profiles 테이블에 couple_id 외래키 추가
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_profiles_couple_id'
        AND conrelid = 'public.profiles'::regclass
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT fk_profiles_couple_id
        FOREIGN KEY (couple_id) REFERENCES public.couples(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_couples_code ON public.couples(code);
CREATE INDEX IF NOT EXISTS idx_messages_couple_id ON public.messages(couple_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_couple_id ON public.profiles(couple_id);

-- 기본 데이터 검증
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'messages_content_length_check'
    ) THEN
        ALTER TABLE public.messages
        ADD CONSTRAINT messages_content_length_check
        CHECK (char_length(content) BETWEEN 1 AND 100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'couples_code_length_check'
    ) THEN
        ALTER TABLE public.couples
        ADD CONSTRAINT couples_code_length_check
        CHECK (char_length(code) = 6);
    END IF;
END $$;

-- Row Level Security (RLS) 활성화
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- profiles 정책: 본인과 연결된 파트너 프로필만 읽기 가능
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own and partner profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "Users can view own and partner profiles"
ON public.profiles FOR SELECT
USING (
    auth.uid() = id
    OR EXISTS (
        SELECT 1 FROM public.couples c
        WHERE c.id = profiles.couple_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- couples 정책: 커플 멤버만 읽기 가능, 인증 사용자는 본인 커플 생성 가능
-- 커플 참여/해제는 직접 UPDATE가 아니라 RPC 또는 Edge Function으로만 처리합니다.
DROP POLICY IF EXISTS "Couple members can view their couple" ON public.couples;
DROP POLICY IF EXISTS "Authenticated users can create couple" ON public.couples;
DROP POLICY IF EXISTS "Couple members can update couple" ON public.couples;

CREATE POLICY "Couple members can view their couple"
ON public.couples FOR SELECT
USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Authenticated users can create couple"
ON public.couples FOR INSERT
WITH CHECK (auth.uid() = user1_id);

-- messages 정책: 커플 멤버만 메시지 읽기/쓰기 가능
DROP POLICY IF EXISTS "Couple members can view messages" ON public.messages;
DROP POLICY IF EXISTS "Couple members can send messages" ON public.messages;

CREATE POLICY "Couple members can view messages"
ON public.messages FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.couples
        WHERE id = couple_id
        AND (user1_id = auth.uid() OR user2_id = auth.uid())
    )
);

CREATE POLICY "Couple members can send messages"
ON public.messages FOR INSERT
WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
        SELECT 1 FROM public.couples
        WHERE id = couple_id
        AND (user1_id = auth.uid() OR user2_id = auth.uid())
    )
);

-- 프로필 자동 생성 트리거 (새 사용자 가입 시)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, nickname)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', '사용자'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 트리거 생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 코드로 커플 찾기 함수
CREATE OR REPLACE FUNCTION public.find_couple_by_code(input_code TEXT)
RETURNS TABLE (
    id UUID,
    code TEXT,
    user1_id UUID,
    user2_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.code, c.user1_id, c.user2_id
    FROM public.couples c
    WHERE c.code = input_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 커플 연결 함수 (user2 참여)
CREATE OR REPLACE FUNCTION public.join_couple(input_code TEXT, joining_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    couple_record RECORD;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> joining_user_id THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = joining_user_id
        AND couple_id IS NOT NULL
    ) THEN
        RETURN FALSE;
    END IF;

    -- 코드로 커플 찾기
    SELECT * INTO couple_record
    FROM public.couples
    WHERE code = input_code AND user2_id IS NULL;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- 본인이 만든 코드는 참여 불가
    IF couple_record.user1_id = joining_user_id THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = couple_record.user1_id
        AND couple_id IS DISTINCT FROM couple_record.id
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- user2 업데이트
    UPDATE public.couples
    SET user2_id = joining_user_id, updated_at = NOW()
    WHERE id = couple_record.id;
    
    -- 두 사용자의 couple_id 업데이트
    UPDATE public.profiles
    SET couple_id = couple_record.id, updated_at = NOW()
    WHERE id IN (couple_record.user1_id, joining_user_id);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 커플 연결 해제 함수
CREATE OR REPLACE FUNCTION public.disconnect_couple(disconnecting_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    couple_record RECORD;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> disconnecting_user_id THEN
        RETURN FALSE;
    END IF;

    SELECT c.* INTO couple_record
    FROM public.couples c
    INNER JOIN public.profiles p ON p.couple_id = c.id
    WHERE p.id = disconnecting_user_id
    AND (c.user1_id = disconnecting_user_id OR c.user2_id = disconnecting_user_id);

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    DELETE FROM public.couples
    WHERE id = couple_record.id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Realtime 활성화 (Supabase 대시보드에서도 설정 필요)
-- Database > Replication > 해당 테이블 활성화
