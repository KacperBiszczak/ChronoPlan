-- CreateEnum
CREATE TYPE "BudgetMode" AS ENUM ('PRIVATE', 'SHARED', 'MIXED');

-- CreateEnum
CREATE TYPE "ExpenseVisibility" AS ENUM ('ORGANIZER_ONLY', 'PARTICIPANTS');

-- CreateEnum
CREATE TYPE "ExpenseSettlementType" AS ENUM ('NONE', 'SPLIT_EQUALLY');

-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "budgetMode" "BudgetMode" NOT NULL DEFAULT 'SHARED';

-- AlterTable
ALTER TABLE "Expense" ADD COLUMN     "category" TEXT,
ADD COLUMN     "settlementType" "ExpenseSettlementType" NOT NULL DEFAULT 'SPLIT_EQUALLY',
ADD COLUMN     "visibility" "ExpenseVisibility" NOT NULL DEFAULT 'PARTICIPANTS';
