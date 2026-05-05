-- Pairing, push-token, and account-deletion hardening for TestFlight readiness.

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

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own and partner profiles" ON public.profiles;
DROP POLICY IF EXISTS "Couple members can update couple" ON public.couples;

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

DO $$
BEGIN
    IF to_regclass('public.device_tokens') IS NOT NULL THEN
        EXECUTE 'DROP POLICY IF EXISTS "Service role can read all device tokens" ON public.device_tokens';
    END IF;
END $$;

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

    SELECT * INTO couple_record
    FROM public.couples
    WHERE code = input_code AND user2_id IS NULL;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

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

    UPDATE public.couples
    SET user2_id = joining_user_id, updated_at = NOW()
    WHERE id = couple_record.id;

    UPDATE public.profiles
    SET couple_id = couple_record.id, updated_at = NOW()
    WHERE id IN (couple_record.user1_id, joining_user_id);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
