-- CreateTable
CREATE TABLE "GoogleCalendarEventSync" (
    "id" SERIAL NOT NULL,
    "eventId" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "googleCalendarEventId" TEXT NOT NULL,
    "syncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GoogleCalendarEventSync_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "GoogleCalendarEventSync_eventId_idx" ON "GoogleCalendarEventSync"("eventId");

-- CreateIndex
CREATE INDEX "GoogleCalendarEventSync_userId_idx" ON "GoogleCalendarEventSync"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "GoogleCalendarEventSync_eventId_userId_key" ON "GoogleCalendarEventSync"("eventId", "userId");

-- AddForeignKey
ALTER TABLE "GoogleCalendarEventSync" ADD CONSTRAINT "GoogleCalendarEventSync_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GoogleCalendarEventSync" ADD CONSTRAINT "GoogleCalendarEventSync_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
