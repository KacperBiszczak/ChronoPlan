import { BudgetMode } from "@prisma/client";

import { prisma } from "./prisma";

const budgetUserSelect = {
  id: true,
  name: true,
  email: true,
  avatarUrl: true,
};

export const settlementInclude = {
  fromUser: {
    select: budgetUserSelect,
  },
  toUser: {
    select: budgetUserSelect,
  },
};

type BudgetEvent = {
  id: number;
  creatorId: number;
  budgetMode: BudgetMode;
};

type BudgetUser = {
  id: number;
  name: string;
  email: string;
  avatarUrl: string | null;
};

type GeneratedSettlement = {
  from: BudgetUser;
  to: BudgetUser;
  amount: number;
};

const roundMoney = (amount: number) => {
  return Math.round((amount + Number.EPSILON) * 100) / 100;
};

export const serializeSettlement = (
  settlement: Awaited<ReturnType<typeof syncSettlementsForEvent>>[number],
) => {
  return {
    id: settlement.id,
    eventId: settlement.eventId,
    fromUserId: settlement.fromUserId,
    toUserId: settlement.toUserId,
    from: settlement.fromUser,
    to: settlement.toUser,
    amount: settlement.amount,
    status: settlement.status,
    paidAt: settlement.paidAt,
    confirmedAt: settlement.confirmedAt,
    createdAt: settlement.createdAt,
    updatedAt: settlement.updatedAt,
  };
};

export const buildBudgetSummaryForEvent = async (
  event: BudgetEvent,
  currentUserId: number,
) => {
  const isOrganizer = event.creatorId === currentUserId;

  if (!isOrganizer && event.budgetMode === "PRIVATE") {
    return {
      budgetMode: event.budgetMode,
      hidden: true,
      currentUserId,
      totalExpenses: 0,
      settledExpensesTotal: 0,
      unassignedExpensesTotal: 0,
      participantCount: 0,
      perPersonShare: 0,
      myBalance: 0,
      pendingSettlementsCount: 0,
      awaitingConfirmationSettlementsCount: 0,
      balances: [],
      settlements: [],
    };
  }

  const expenseWhere =
    isOrganizer || event.budgetMode === "SHARED"
      ? {
          eventId: event.id,
        }
      : {
          eventId: event.id,
          visibility: "PARTICIPANTS" as const,
        };

  const expenses = await prisma.expense.findMany({
    where: expenseWhere,
    include: {
      paidBy: {
        select: budgetUserSelect,
      },
    },
  });

  const creator = await prisma.user.findUnique({
    where: {
      id: event.creatorId,
    },
    select: budgetUserSelect,
  });

  const acceptedParticipants = await prisma.eventParticipant.findMany({
    where: {
      eventId: event.id,
      status: "ACCEPTED",
    },
    include: {
      user: {
        select: budgetUserSelect,
      },
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  const settlementUsers = [
    ...(creator ? [creator] : []),
    ...acceptedParticipants
      .map((participant) => participant.user)
      .filter((participantUser) => participantUser.id !== event.creatorId),
  ];

  const splitExpenses = expenses.filter((expense) => {
    return expense.settlementType === "SPLIT_EQUALLY";
  });

  const settledExpenses = splitExpenses.filter((expense) => {
    return expense.paidById !== null;
  });

  const unassignedExpenses = splitExpenses.filter((expense) => {
    return expense.paidById === null;
  });

  const totalExpenses = roundMoney(
    expenses.reduce((sum, expense) => {
      return sum + expense.amount;
    }, 0),
  );

  const settledExpensesTotal = roundMoney(
    settledExpenses.reduce((sum, expense) => {
      return sum + expense.amount;
    }, 0),
  );

  const unassignedExpensesTotal = roundMoney(
    unassignedExpenses.reduce((sum, expense) => {
      return sum + expense.amount;
    }, 0),
  );

  if (settlementUsers.length === 0) {
    const settlements = await syncSettlementsForEvent(event.id, []);

    return {
      budgetMode: event.budgetMode,
      hidden: false,
      currentUserId,
      totalExpenses,
      settledExpensesTotal,
      unassignedExpensesTotal,
      participantCount: 0,
      perPersonShare: 0,
      myBalance: 0,
      pendingSettlementsCount: settlements.filter(
        (settlement) => settlement.status === "PENDING",
      ).length,
      awaitingConfirmationSettlementsCount: settlements.filter(
        (settlement) => settlement.status === "MARKED_AS_PAID",
      ).length,
      balances: [],
      settlements: settlements.map(serializeSettlement),
    };
  }

  const perPersonShare = roundMoney(
    settledExpensesTotal / settlementUsers.length,
  );

  const balances = settlementUsers.map((settlementUser) => {
    const paid = roundMoney(
      settledExpenses
        .filter((expense) => expense.paidById === settlementUser.id)
        .reduce((sum, expense) => {
          return sum + expense.amount;
        }, 0),
    );

    const balance = roundMoney(paid - perPersonShare);

    return {
      user: settlementUser,
      paid,
      share: perPersonShare,
      balance,
    };
  });

  const generatedSettlements = generateSettlementsFromBalances(balances);
  const settlements = await syncSettlementsForEvent(
    event.id,
    generatedSettlements,
  );

  const myBalance =
    balances.find((balance) => balance.user.id === currentUserId)?.balance ?? 0;

  return {
    budgetMode: event.budgetMode,
    hidden: false,
    currentUserId,
    totalExpenses,
    settledExpensesTotal,
    unassignedExpensesTotal,
    participantCount: settlementUsers.length,
    perPersonShare,
    myBalance,
    pendingSettlementsCount: settlements.filter(
      (settlement) => settlement.status === "PENDING",
    ).length,
    awaitingConfirmationSettlementsCount: settlements.filter(
      (settlement) => settlement.status === "MARKED_AS_PAID",
    ).length,
    balances,
    settlements: settlements.map(serializeSettlement),
  };
};

export const syncSettlementsForEvent = async (
  eventId: number,
  generatedSettlements: GeneratedSettlement[],
) => {
  const existingSettlements = await prisma.settlement.findMany({
    where: {
      eventId,
    },
    include: settlementInclude,
  });

  const activeKeys = new Set<string>();

  for (const generatedSettlement of generatedSettlements) {
    const amount = roundMoney(generatedSettlement.amount);
    const key = settlementKey(
      generatedSettlement.from.id,
      generatedSettlement.to.id,
    );

    activeKeys.add(key);

    const existingSettlement = existingSettlements.find((settlement) => {
      return (
        settlement.fromUserId === generatedSettlement.from.id &&
        settlement.toUserId === generatedSettlement.to.id
      );
    });

    if (!existingSettlement) {
      await prisma.settlement.create({
        data: {
          eventId,
          fromUserId: generatedSettlement.from.id,
          toUserId: generatedSettlement.to.id,
          amount,
        },
      });
      continue;
    }

    const amountChanged = Math.abs(existingSettlement.amount - amount) > 0.01;
    const shouldResetStatus =
      existingSettlement.status === "CANCELLED" || amountChanged;

    if (amountChanged || shouldResetStatus) {
      await prisma.settlement.update({
        where: {
          id: existingSettlement.id,
        },
        data: {
          amount,
          ...(shouldResetStatus
            ? {
                status: "PENDING",
                paidAt: null,
                confirmedAt: null,
              }
            : {}),
        },
      });
    }
  }

  for (const existingSettlement of existingSettlements) {
    const key = settlementKey(
      existingSettlement.fromUserId,
      existingSettlement.toUserId,
    );

    if (
      activeKeys.has(key) ||
      existingSettlement.status === "CONFIRMED" ||
      existingSettlement.status === "CANCELLED"
    ) {
      continue;
    }

    await prisma.settlement.update({
      where: {
        id: existingSettlement.id,
      },
      data: {
        status: "CANCELLED",
      },
    });
  }

  return prisma.settlement.findMany({
    where: {
      eventId,
    },
    include: settlementInclude,
    orderBy: [
      {
        createdAt: "asc",
      },
    ],
  });
};

const generateSettlementsFromBalances = (
  balances: {
    user: BudgetUser;
    balance: number;
  }[],
): GeneratedSettlement[] => {
  const creditors = balances
    .filter((item) => item.balance > 0.01)
    .map((item) => ({
      user: item.user,
      amount: item.balance,
    }));

  const debtors = balances
    .filter((item) => item.balance < -0.01)
    .map((item) => ({
      user: item.user,
      amount: Math.abs(item.balance),
    }));

  const settlements: GeneratedSettlement[] = [];

  let debtorIndex = 0;
  let creditorIndex = 0;

  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    const debtor = debtors[debtorIndex];
    const creditor = creditors[creditorIndex];

    if (!debtor || !creditor) {
      break;
    }

    const amount = roundMoney(Math.min(debtor.amount, creditor.amount));

    if (amount > 0.01) {
      settlements.push({
        from: debtor.user,
        to: creditor.user,
        amount,
      });
    }

    debtor.amount = roundMoney(debtor.amount - amount);
    creditor.amount = roundMoney(creditor.amount - amount);

    if (debtor.amount <= 0.01) {
      debtorIndex += 1;
    }

    if (creditor.amount <= 0.01) {
      creditorIndex += 1;
    }
  }

  return settlements;
};

const settlementKey = (fromUserId: number, toUserId: number) => {
  return `${fromUserId}:${toUserId}`;
};
