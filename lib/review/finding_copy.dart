import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';

/// What a Finding says on screen: a short subject and the sentence under it.
/// The Check reports kinds carrying values and no words at all, so this switch
/// is the only place the words are chosen. It is exhaustive on purpose — a kind
/// added without copy is a compile error rather than a blank line on somebody's
/// receipt.
///
/// Takes the words rather than a `BuildContext`, so the whole set stays
/// readable in both languages from a unit test.
(String, String) sayingFor(
  AppLocalizations words,
  Finding finding,
) => switch (finding) {
  NotAReceipt() => (
    words.reviewFindingNotAReceiptTitle,
    words.reviewFindingNotAReceiptDetail,
  ),
  NoTotal() => (
    words.reviewFindingNoTotalTitle,
    words.reviewFindingNoTotalDetail,
  ),
  NoMerchant() => (
    words.reviewFindingNoMerchantTitle,
    words.reviewFindingNoMerchantDetail,
  ),
  NoDate() => (words.reviewFindingNoDateTitle, words.reviewFindingNoDateDetail),
  UnparseableDate(:final read) => (
    words.reviewFindingUnparseableDateTitle,
    words.reviewFindingUnparseableDateDetail(read),
  ),
  DateInTheFuture(:final read) => (
    words.reviewFindingDateInTheFutureTitle,
    words.reviewFindingDateInTheFutureDetail(read),
  ),
  YearLooksMisread(:final read, :final likelyYear) => (
    words.reviewFindingYearLooksMisreadTitle,
    words.reviewFindingYearLooksMisreadDetail(read, likelyYear),
  ),
  DateIsUnusuallyOld(:final read, :final daysAgo) => (
    words.reviewFindingDateIsUnusuallyOldTitle,
    words.reviewFindingDateIsUnusuallyOldDetail(read, daysAgo),
  ),
  NoCurrency() => (
    words.reviewFindingCurrencyUnclearTitle,
    words.reviewFindingNoCurrencyDetail,
  ),
  CurrencyNotAnIsoCode(:final read) => (
    words.reviewFindingCurrencyUnclearTitle,
    words.reviewFindingCurrencyNotAnIsoCodeDetail(read),
  ),
  TotalDoesNotAddUp() => (
    words.reviewFindingTotalDoesNotAddUpTitle,
    words.reviewFindingTotalDoesNotAddUpDetail(
      _money(finding.subtotal),
      _money(finding.tax),
      _money(finding.tip),
      _money(finding.composed),
      _money(finding.total),
      _money(finding.difference),
    ),
  ),
  // Four whole sentences rather than one with the target named by a
  // placeholder: "subtotal" glued into a translated sentence is the
  // fragment concatenation the message files exist to prevent.
  LineItemsDoNotMatch(:final sum, :final target, :final over) => (
    finding.againstSubtotal
        ? words.reviewFindingLineItemsDoNotMatchSubtotalTitle
        : words.reviewFindingLineItemsDoNotMatchTotalTitle,
    switch ((finding.againstSubtotal, over)) {
      (true, false) => words.reviewFindingLineItemsUnderSubtotalDetail(
        _money(sum),
        _money(target),
      ),
      (true, true) => words.reviewFindingLineItemsOverSubtotalDetail(
        _money(sum),
        _money(target),
      ),
      (false, false) => words.reviewFindingLineItemsUnderTotalDetail(
        _money(sum),
        _money(target),
      ),
      (false, true) => words.reviewFindingLineItemsOverTotalDetail(
        _money(sum),
        _money(target),
      ),
    },
  ),
  LineArithmeticOff(:final description, :final quantity, :final unitPrice) => (
    words.reviewFindingLineArithmeticOffTitle,
    words.reviewFindingLineArithmeticOffDetail(
      description,
      _money(quantity),
      _money(unitPrice),
      _money(finding.expected),
      _money(finding.amount),
    ),
  ),
  UnknownItemCategory(:final description, :final read) => (
    words.reviewFindingUnknownItemCategoryTitle,
    words.reviewFindingUnknownItemCategoryDetail(description, read),
  ),
  UnknownCategory(:final read) => (
    words.reviewFindingUnknownCategoryTitle,
    words.reviewFindingUnknownCategoryDetail(read),
  ),
  UnknownPaymentMethod(:final read) => (
    words.reviewFindingUnknownPaymentMethodTitle,
    words.reviewFindingUnknownPaymentMethodDetail(read),
  ),
  // The reasons are the Model's own words, so there is no sentence here to
  // translate — only the punctuation between them, and only when it gave
  // more than one.
  ModelAskedForReview(:final reasons) => (
    words.reviewFindingModelAskedForReviewTitle,
    reasons.isEmpty
        ? words.reviewFindingModelAskedNoReasonDetail
        : reasons.join(words.reviewFindingReasonSeparator),
  ),
};

/// Two decimal places and no locale, the same rule money follows everywhere
/// else in the app: a familiar decimal separator on an amount whose currency is
/// stated explicitly would be a guess about which currency it is. See
/// `asMoney` in `on_screen.dart`.
String _money(double value) => value.toStringAsFixed(2);
