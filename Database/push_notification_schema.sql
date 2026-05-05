-- Push Notification을 위한 추가 스키마
-- Supabase SQL Editor에서 실행하세요

-- 1. device_tokens 테이블: 디바이스 푸시 토큰 저장
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

-- RLS 활성화
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- device_tokens 정책
DROP POLICY IF EXISTS "Users can manage own device tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Service role can read all device tokens" ON public.device_tokens;

CREATE POLICY "Users can manage own device tokens"
ON public.device_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Edge Function은 service role key를 사용하므로 별도 공개 SELECT 정책이 필요 없습니다.

-- 3. 메시지 전송 시 푸시 알림을 트리거하는 함수
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    receiver_id UUID;
    couple_record RECORD;
BEGIN
    -- 커플 정보 가져오기
    SELECT * INTO couple_record
    FROM public.couples
    WHERE id = NEW.couple_id;
    
    -- 수신자 ID 결정 (발신자가 아닌 사람)
    IF couple_record.user1_id = NEW.sender_id THEN
        receiver_id := couple_record.user2_id;
    ELSE
        receiver_id := couple_record.user1_id;
    END IF;
    
    -- 수신자가 있는 경우에만 알림
    IF receiver_id IS NOT NULL THEN
        -- Edge Function 호출을 위한 pg_notify
        PERFORM pg_notify(
            'new_message',
            json_build_object(
                'message_id', NEW.id,
                'couple_id', NEW.couple_id,
                'sender_id', NEW.sender_id,
                'receiver_id', receiver_id,
                'content', NEW.content
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. 메시지 INSERT 시 트리거
DROP TRIGGER IF EXISTS on_new_message ON public.messages;
CREATE TRIGGER on_new_message
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();
