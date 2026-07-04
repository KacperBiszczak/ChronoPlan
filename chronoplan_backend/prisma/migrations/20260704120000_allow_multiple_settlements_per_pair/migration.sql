-- DropIndex
DROP INDEX IF EXISTS "Settlement_eventId_fromUserId_toUserId_key";

-- CreateIndex
CREATE INDEX IF NOT EXISTS "Settlement_eventId_fromUserId_toUserId_idx" ON "Settlement"("eventId", "fromUserId", "toUserId");
