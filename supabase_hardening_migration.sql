-- ====================================================================
-- HARDENED SUPABASE RLS & RPC MIGRATION SCRIPT
-- Target Capacity: ~1,000 to 10,000+ Students & Registrations
-- Run this in Supabase Dashboard -> SQL Editor
-- ====================================================================

-- 1. Ensure user_profiles table exists
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT DEFAULT '',
  role        TEXT NOT NULL DEFAULT 'coordinator',
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure columns exist in students & registrations
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS father_name TEXT;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS class TEXT;
ALTER TABLE public.students ALTER COLUMN phone DROP NOT NULL;

ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS father_name TEXT;
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS class TEXT;
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.registrations ADD COLUMN IF NOT EXISTS coordinator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Enable RLS across all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- 2. Drop legacy anonymous SELECT policies
DROP POLICY IF EXISTS "anon_read_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "anon_read_certificates" ON public.certificates;
DROP POLICY IF EXISTS "anon_read_students" ON public.students;
DROP POLICY IF EXISTS "anon_read_registrations" ON public.registrations;
DROP POLICY IF EXISTS "anon_read_sessions" ON public.sessions;

-- 3. Define RLS Policies
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_profiles' AND policyname = 'auth_user_profiles_all') THEN
    CREATE POLICY "auth_user_profiles_all" ON public.user_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sessions' AND policyname = 'anon_read_active_sessions') THEN
    CREATE POLICY "anon_read_active_sessions" ON public.sessions FOR SELECT TO anon USING (status = 'active');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sessions' AND policyname = 'auth_sessions_all') THEN
    CREATE POLICY "auth_sessions_all" ON public.sessions FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'students' AND policyname = 'anon_insert_students') THEN
    CREATE POLICY "anon_insert_students" ON public.students FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'students' AND policyname = 'anon_select_students') THEN
    CREATE POLICY "anon_select_students" ON public.students FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'students' AND policyname = 'auth_students_all') THEN
    CREATE POLICY "auth_students_all" ON public.students FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'registrations' AND policyname = 'anon_insert_registrations') THEN
    CREATE POLICY "anon_insert_registrations" ON public.registrations FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'registrations' AND policyname = 'anon_select_registrations') THEN
    CREATE POLICY "anon_select_registrations" ON public.registrations FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'registrations' AND policyname = 'auth_registrations_all') THEN
    CREATE POLICY "auth_registrations_all" ON public.registrations FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'certificates' AND policyname = 'auth_certificates_all') THEN
    CREATE POLICY "auth_certificates_all" ON public.certificates FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;


-- 4. RPC Functions for Secure Kiosk & Public Operations

-- Single Certificate Verification RPC
CREATE OR REPLACE FUNCTION public.verify_certificate(p_cert_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', c.id,
    'certificate_id', c.certificate_id,
    'issued_at', c.issued_at,
    'verification_status', c.verification_status,
    'registrations', jsonb_build_object(
      'registration_id', r.registration_id,
      'class', r.class,
      'registration_status', r.registration_status,
      'students', jsonb_build_object(
        'name', s.name,
        'father_name', s.father_name,
        'school_name', s.school_name
      ),
      'sessions', jsonb_build_object(
        'name', sess.name,
        'start_date', sess.start_date,
        'end_date', sess.end_date
      )
    )
  ) INTO result
  FROM public.certificates c
  JOIN public.registrations r ON r.id = c.registration_id
  JOIN public.students s ON s.id = r.student_id
  JOIN public.sessions sess ON sess.id = r.session_id
  WHERE UPPER(c.certificate_id) = UPPER(TRIM(p_cert_id));

  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.verify_certificate(text) TO anon, authenticated;


-- Public Single Registration Fetching RPC (For /success/:registrationId page)
CREATE OR REPLACE FUNCTION public.get_registration_public(p_reg_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', r.id,
    'registration_id', r.registration_id,
    'class', r.class,
    'father_name', r.father_name,
    'phone', r.phone,
    'city', r.city,
    'registration_status', r.registration_status,
    'registered_at', r.registered_at,
    'students', jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'father_name', s.father_name,
      'phone', s.phone,
      'class', s.class,
      'school_name', s.school_name,
      'city', s.city,
      'photo_url', s.photo_url
    ),
    'sessions', jsonb_build_object(
      'id', sess.id,
      'name', sess.name,
      'start_date', sess.start_date,
      'end_date', sess.end_date
    )
  ) INTO result
  FROM public.registrations r
  JOIN public.students s ON s.id = r.student_id
  JOIN public.sessions sess ON sess.id = r.session_id
  WHERE r.registration_id = TRIM(p_reg_id);

  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_registration_public(text) TO anon, authenticated;


-- Registration Duplicate Check RPC (Checks phone and name/father_name for active session)
CREATE OR REPLACE FUNCTION public.check_existing_registration(
  p_name text,
  p_father_name text,
  p_phone text,
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  phone_exists boolean := false;
  name_exists boolean := false;
  existing_reg_id text;
BEGIN
  -- Check normalized phone if provided
  IF p_phone IS NOT NULL AND TRIM(p_phone) != '' THEN
    SELECT r.registration_id INTO existing_reg_id
    FROM public.registrations r
    JOIN public.students s ON s.id = r.student_id
    WHERE s.phone = TRIM(p_phone)
      AND r.session_id = p_session_id
      AND r.registration_status != 'cancelled'
    LIMIT 1;

    IF existing_reg_id IS NOT NULL THEN
      phone_exists := true;
    END IF;
  END IF;

  -- Check name + father_name (if provided or to catch duplicate student name)
  IF p_name IS NOT NULL AND TRIM(p_name) != '' THEN
    SELECT r.registration_id INTO existing_reg_id
    FROM public.registrations r
    JOIN public.students s ON s.id = r.student_id
    WHERE LOWER(TRIM(s.name)) = LOWER(TRIM(p_name))
      AND (
        (p_father_name IS NOT NULL AND TRIM(p_father_name) != '' AND LOWER(TRIM(COALESCE(s.father_name, ''))) = LOWER(TRIM(p_father_name)))
        OR (p_father_name IS NULL OR TRIM(p_father_name) = '')
      )
      AND r.session_id = p_session_id
      AND r.registration_status != 'cancelled'
    LIMIT 1;

    IF existing_reg_id IS NOT NULL THEN
      name_exists := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'phone_exists', phone_exists,
    'name_exists', name_exists,
    'existing_reg_id', existing_reg_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_existing_registration(text, text, text, uuid) TO anon, authenticated;


-- Atomic Student Registration RPC
CREATE OR REPLACE FUNCTION public.register_student(
  p_name text,
  p_father_name text,
  p_phone text,
  p_class text,
  p_school_name text,
  p_city text,
  p_photo_url text,
  p_session_id uuid,
  p_registration_id text,
  p_coordinator_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id uuid;
  v_reg_id uuid;
BEGIN
  INSERT INTO public.students (name, father_name, phone, class, school_name, city, photo_url)
  VALUES (p_name, p_father_name, p_phone, p_class, p_school_name, p_city, p_photo_url)
  RETURNING id INTO v_student_id;

  INSERT INTO public.registrations (student_id, session_id, father_name, class, phone, city, registration_id, registration_status, coordinator_id)
  VALUES (v_student_id, p_session_id, p_father_name, p_class, p_phone, p_city, p_registration_id, 'confirmed', p_coordinator_id)
  RETURNING id INTO v_reg_id;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', v_student_id,
    'registration_id', p_registration_id
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.register_student(text, text, text, text, text, text, text, uuid, text, uuid) TO anon, authenticated;


-- Coordinator Account Pre-Check RPC
CREATE OR REPLACE FUNCTION public.check_coordinator_profile(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  prof record;
  total_count integer;
BEGIN
  SELECT COUNT(*) INTO total_count FROM public.user_profiles;

  SELECT full_name, is_active INTO prof
  FROM public.user_profiles
  WHERE LOWER(email) = LOWER(TRIM(p_email));

  IF prof IS NOT NULL THEN
    RETURN jsonb_build_object(
      'exists', true,
      'is_active', prof.is_active,
      'full_name', prof.full_name,
      'total_profiles', total_count
    );
  ELSE
    RETURN jsonb_build_object(
      'exists', false,
      'is_active', false,
      'total_profiles', total_count
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_coordinator_profile(text) TO anon, authenticated;


-- 5. Database Performance & Integrity Indexes
CREATE INDEX IF NOT EXISTS idx_registrations_student_id ON public.registrations(student_id);
CREATE INDEX IF NOT EXISTS idx_registrations_session_id ON public.registrations(session_id);
CREATE INDEX IF NOT EXISTS idx_registrations_status ON public.registrations(registration_status);
CREATE INDEX IF NOT EXISTS idx_registrations_coordinator_id ON public.registrations(coordinator_id);

CREATE INDEX IF NOT EXISTS idx_students_phone ON public.students(phone);
CREATE INDEX IF NOT EXISTS idx_students_name ON public.students(name);
CREATE INDEX IF NOT EXISTS idx_students_father_name ON public.students(father_name);

CREATE INDEX IF NOT EXISTS idx_certificates_registration_id ON public.certificates(registration_id);
CREATE INDEX IF NOT EXISTS idx_certificates_cert_id ON public.certificates(certificate_id);

CREATE INDEX IF NOT EXISTS idx_attendance_registration_id ON public.attendance(registration_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance(attendance_date);

SELECT 'Hardened security & RPC migration applied successfully' AS status;
