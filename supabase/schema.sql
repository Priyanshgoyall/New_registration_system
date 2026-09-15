-- ============================================================
-- Sports Registration System - Complete Supabase PostgreSQL Schema
-- Run this script in Supabase Dashboard → SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

-- 1. Students Table
CREATE TABLE IF NOT EXISTS public.students (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  father_name   TEXT,
  phone         TEXT, -- Optional
  class         TEXT,
  school_name   TEXT NOT NULL,
  city          TEXT,
  photo_url     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure columns exist if migrating existing database
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS father_name TEXT;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS class TEXT;
ALTER TABLE public.students ALTER COLUMN phone DROP NOT NULL;

-- 2. Sessions Table
CREATE TABLE IF NOT EXISTS public.sessions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  description   TEXT,
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  status        TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','active','completed','cancelled')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Registrations Table
CREATE TABLE IF NOT EXISTS public.registrations (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id            UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  session_id            UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  father_name           TEXT,
  class                 TEXT,
  phone                 TEXT,
  city                  TEXT,
  registration_id       TEXT NOT NULL UNIQUE,
  registration_status   TEXT NOT NULL DEFAULT 'confirmed' CHECK (registration_status IN ('pending','confirmed','cancelled')),
  registered_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  coordinator_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE(student_id, session_id)
);

-- 4. Attendance Table
CREATE TABLE IF NOT EXISTS public.attendance (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  registration_id   UUID NOT NULL REFERENCES public.registrations(id) ON DELETE CASCADE,
  attendance_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  status            TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present','absent','late')),
  UNIQUE(registration_id, attendance_date)
);

-- 5. Certificates Table
CREATE TABLE IF NOT EXISTS public.certificates (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  registration_id       UUID NOT NULL REFERENCES public.registrations(id) ON DELETE CASCADE,
  certificate_id        TEXT NOT NULL UNIQUE,
  certificate_url       TEXT,
  issued_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verification_status   TEXT NOT NULL DEFAULT 'valid' CHECK (verification_status IN ('valid','revoked')),
  UNIQUE(registration_id)
);

-- 6. User Profiles Table (Desk Coordinators & Admins)
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT DEFAULT '',
  role        TEXT NOT NULL DEFAULT 'coordinator',
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_students_name ON public.students(name);
CREATE INDEX IF NOT EXISTS idx_students_phone ON public.students(phone);
CREATE INDEX IF NOT EXISTS idx_students_father_name ON public.students(father_name);
CREATE INDEX IF NOT EXISTS idx_registrations_student_id ON public.registrations(student_id);
CREATE INDEX IF NOT EXISTS idx_registrations_session_id ON public.registrations(session_id);
CREATE INDEX IF NOT EXISTS idx_registrations_coordinator_id ON public.registrations(coordinator_id);
CREATE INDEX IF NOT EXISTS idx_attendance_registration_id ON public.attendance(registration_id);
CREATE INDEX IF NOT EXISTS idx_certificates_registration_id ON public.certificates(registration_id);
CREATE INDEX IF NOT EXISTS idx_certificates_certificate_id ON public.certificates(certificate_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS students_updated_at ON public.students;
CREATE TRIGGER students_updated_at
  BEFORE UPDATE ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('student-photos', 'student-photos', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('certificates', 'certificates', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Students RLS
CREATE POLICY "anon_insert_students" ON public.students FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_select_students" ON public.students FOR SELECT TO anon USING (true);
CREATE POLICY "auth_students_all" ON public.students FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Sessions RLS
CREATE POLICY "anon_read_active_sessions" ON public.sessions FOR SELECT TO anon USING (status = 'active');
CREATE POLICY "auth_sessions_all" ON public.sessions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Registrations RLS
CREATE POLICY "anon_insert_registrations" ON public.registrations FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_select_registrations" ON public.registrations FOR SELECT TO anon USING (true);
CREATE POLICY "auth_registrations_all" ON public.registrations FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Attendance RLS
CREATE POLICY "auth_attendance_all" ON public.attendance FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Certificates RLS
CREATE POLICY "auth_certificates_all" ON public.certificates FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- User Profiles RLS
CREATE POLICY "auth_user_profiles_all" ON public.user_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Storage Objects Policies
CREATE POLICY "public_read_photos" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'student-photos');
CREATE POLICY "anon_upload_photos" ON storage.objects FOR INSERT TO anon WITH CHECK (bucket_id = 'student-photos');
CREATE POLICY "auth_manage_photos" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'student-photos');
CREATE POLICY "public_read_certs" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'certificates');
CREATE POLICY "auth_manage_certs" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'certificates');

