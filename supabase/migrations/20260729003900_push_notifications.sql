-- Migration: Push Notification Token support
-- Run this in Supabase SQL Editor or via supabase db push

-- Add push_token column to profiles table
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS push_token TEXT,
  ADD COLUMN IF NOT EXISTS push_token_updated_at TIMESTAMPTZ;

-- Index for fast token lookups
CREATE INDEX IF NOT EXISTS idx_profiles_push_token ON profiles (id) WHERE push_token IS NOT NULL;

COMMENT ON COLUMN profiles.push_token IS 'Firebase Cloud Messaging (FCM) device token for push notifications';
