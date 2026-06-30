-- CreateEnum
CREATE TYPE "DateVoteStatus" AS ENUM ('YES', 'MAYBE', 'NO');

-- CreateTable
CREATE TABLE "DateOption" (
    "id" SERIAL NOT NULL,
    "proposedDate" TIMESTAMP(3) NOT NULL,
    "eventId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DateOption_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DateVote" (
    "id" SERIAL NOT NULL,
    "status" "DateVoteStatus" NOT NULL,
    "optionId" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DateVote_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "DateVote_optionId_userId_key" ON "DateVote"("optionId", "userId");

-- AddForeignKey
ALTER TABLE "DateOption" ADD CONSTRAINT "DateOption_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DateVote" ADD CONSTRAINT "DateVote_optionId_fkey" FOREIGN KEY ("optionId") REFERENCES "DateOption"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DateVote" ADD CONSTRAINT "DateVote_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
