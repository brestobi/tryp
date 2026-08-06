-- Migration: 20260801230000_add_dual_completion_tracking.sql
-- Description: Add columns to track individual completion confirmation by driver and passenger.

ALTER TABLE public.rides
ADD COLUMN IF NOT EXISTS driver_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS passenger_completed BOOLEAN DEFAULT FALSE;
