import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/data/expense_document.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  final groceries = Expense(
    id: 'jaya-grocer-2',
    merchant: 'Jaya Grocer Bangsar',
    date: DateTime(2026, 8, 2),
    currency: 'MYR',
    total: 184.20,
    category: 'groceries',
    lineItems: const [
      LineItem(
        description: 'Milk 2L',
        quantity: 2,
        unitPrice: 9.90,
        amount: 19.80,
        category: 'groceries',
      ),
      LineItem(description: 'Bag', amount: 0.20, category: 'other'),
    ],
    source: ExpenseSource.scanned,
    needsReview: true,
    subtotal: 180.00,
    tax: 4.20,
    paymentMethod: 'card',
    receiptPath: 'jaya-grocer-2.jpg',
    correctedFields: ['total', 'date'],
  );

  test('an Expense written to a document reads back identical', () {
    final read = expenseFromDocument(
      groceries.id,
      expenseToDocument(groceries),
    );

    expect(read.merchant, 'Jaya Grocer Bangsar');
    expect(read.date, DateTime(2026, 8, 2));
    expect(read.currency, 'MYR');
    expect(read.total, 184.20);
    expect(read.category, 'groceries');
    expect(read.source, ExpenseSource.scanned);
    expect(read.needsReview, isTrue);
    expect(read.correctedFields, ['total', 'date']);
  });

  test('line items keep their own quantities, prices and categories', () {
    final read = expenseFromDocument(
      groceries.id,
      expenseToDocument(groceries),
    );

    expect(read.lineItems, hasLength(2));
    expect(read.lineItems.first.description, 'Milk 2L');
    expect(read.lineItems.first.quantity, 2);
    expect(read.lineItems.first.unitPrice, 9.90);
    expect(read.lineItems.first.amount, 19.80);
    expect(read.lineItems.last.category, 'other');
    expect(read.lineItems.last.quantity, isNull);
  });

  test('the document id becomes the Expense id, and is not duplicated inside', () {
    expect(expenseToDocument(groceries), isNot(contains('id')));
    expect(
      expenseFromDocument('somewhere-else', expenseToDocument(groceries)).id,
      'somewhere-else',
    );
  });

  test('a hand-typed Expense stays hand-typed across a round trip', () {
    final typed = Expense(
      id: 'cash-1',
      merchant: 'Kopitiam SS2',
      date: DateTime(2026, 8, 4),
      currency: 'MYR',
      total: 26,
      category: 'dining',
      lineItems: const [],
      source: ExpenseSource.manual,
      needsReview: false,
    );

    expect(
      expenseFromDocument(typed.id, expenseToDocument(typed)).source,
      ExpenseSource.manual,
    );
  });

  test('a document missing every optional field still reads as an Expense', () {
    final read = expenseFromDocument('sparse', {
      'merchant': 'Kopitiam SS2',
      'date': '2026-08-04T00:00:00.000',
      'currency': 'MYR',
      'total': 26,
      'category': 'dining',
    });

    expect(read.merchant, 'Kopitiam SS2');
    expect(read.total, 26);
    expect(read.lineItems, isEmpty);
    expect(read.correctedFields, isEmpty);
    expect(read.needsReview, isFalse);
    expect(read.source, ExpenseSource.scanned);
  });

  test('a document with no total refuses to become an Expense worth 0.00', () {
    expect(
      () => expenseFromDocument('corrupt', {
        'merchant': 'Kopitiam SS2',
        'date': '2026-08-04T00:00:00.000',
        'currency': 'MYR',
        'category': 'dining',
      }),
      throwsFormatException,
    );
  });

  test('a document with an illegible date refuses to be dated 1970', () {
    expect(
      () => expenseFromDocument('corrupt', {
        'merchant': 'Kopitiam SS2',
        'date': 'last Tuesday',
        'currency': 'MYR',
        'total': 26,
        'category': 'dining',
      }),
      throwsFormatException,
    );
  });

  test('an integer total in the document reads as a double', () {
    final read = expenseFromDocument('int-total', {
      ...expenseToDocument(groceries),
      'total': 185,
    });

    expect(read.total, 185.0);
  });

  test('the receipt the Expense was read from is written down with it', () {
    final read = expenseFromDocument(
      groceries.id,
      expenseToDocument(groceries),
    );

    expect(read.receiptPath, 'jaya-grocer-2.jpg');
  });

  test('the arithmetic the Check re-does survives the round trip', () {
    final read = expenseFromDocument(
      groceries.id,
      expenseToDocument(groceries),
    );

    expect(read.subtotal, 180.00);
    expect(read.tax, 4.20);
    expect(read.tip, isNull);
    expect(read.paymentMethod, 'card');
  });

  test('an Expense written before the path was recorded still finds its '
      'receipt', () {
    final document = expenseToDocument(groceries)..remove('receiptPath');

    final read = expenseFromDocument(groceries.id, document);

    expect(
      read.receiptPath,
      'jaya-grocer-2.jpg',
      reason: 'a scanned Expense carries the id of the Scan the photo is '
          'named after',
    );
  });

  test('an Expense typed by hand before the path was recorded has no receipt '
      'invented for it', () {
    final document = expenseToDocument(groceries)
      ..remove('receiptPath')
      ..['source'] = 'manual';

    expect(expenseFromDocument(groceries.id, document).receiptPath, isNull);
  });

  test('an Expense written before there was any of this reads back with the '
      'rest of it intact', () {
    final document = expenseToDocument(groceries)
      ..remove('subtotal')
      ..remove('tax')
      ..remove('paymentMethod');

    final read = expenseFromDocument(groceries.id, document);

    expect(read.subtotal, isNull);
    expect(read.paymentMethod, 'unknown');
    expect(read.total, 184.20);
  });
}
