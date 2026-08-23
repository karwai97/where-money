import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
} from 'firebase/firestore';

const kai = 'kai-uid';
const stranger = 'stranger-uid';

const anExpense = {
  merchant: 'Village Grocer Bangsar',
  date: '2026-08-21T00:00:00.000',
  currency: 'MYR',
  total: 44.1,
  category: 'groceries',
  lineItems: [],
  source: 'scanned',
  needsReview: false,
  correctedFields: [],
};

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-where-money',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(() => testEnv?.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed past the rules, so the read tests are refused rather than empty.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `users/${kai}/expenses/one`), anExpense);
    await setDoc(doc(db, `users/${stranger}/expenses/one`), anExpense);
  });
});

const ledgerOf = (db, uid) => collection(db, `users/${uid}/expenses`);

describe('a signed-in user and their own Ledger', () => {
  it('reads an Expense they own', async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertSucceeds(getDoc(doc(db, `users/${kai}/expenses/one`)));
  });

  it('lists their own Ledger', async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertSucceeds(getDocs(ledgerOf(db, kai)));
  });

  it('writes an Expense into their own Ledger', async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertSucceeds(setDoc(doc(db, `users/${kai}/expenses/two`), anExpense));
  });
});

describe("a signed-in user and somebody else's Ledger", () => {
  it("cannot read another user's Expense", async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertFails(getDoc(doc(db, `users/${stranger}/expenses/one`)));
  });

  it("cannot list another user's Ledger", async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertFails(getDocs(ledgerOf(db, stranger)));
  });

  it("cannot write into another user's Ledger", async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertFails(
      setDoc(doc(db, `users/${stranger}/expenses/two`), anExpense),
    );
  });

  it("cannot overwrite another user's existing Expense", async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertFails(
      setDoc(doc(db, `users/${stranger}/expenses/one`), { total: 0 }),
    );
  });
});

describe('a signed-out client', () => {
  it('cannot read any Ledger', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, `users/${kai}/expenses/one`)));
  });

  it('cannot write any Ledger', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, `users/${kai}/expenses/two`), anExpense));
  });
});

describe('paths the app does not use', () => {
  it('are refused outright, signed in or not', async () => {
    const db = testEnv.authenticatedContext(kai).firestore();
    await assertFails(getDoc(doc(db, 'expenses/one')));
    await assertFails(setDoc(doc(db, 'anything/at/all/here'), anExpense));
  });
});
