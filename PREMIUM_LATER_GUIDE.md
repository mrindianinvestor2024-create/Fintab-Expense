# FinTab Premium — activate later

Premium is prepared for the future, but it is intentionally switched off in V3.4. Users cannot see a subscription button and the app does not start a billing request.

## Current setting

In `lib/main.dart`:

```dart
const premiumProductId = 'fintab_premium_monthly_29';
const premiumSubscriptionsEnabled = false;
```

Keep `premiumSubscriptionsEnabled` set to `false` while the app remains free.

## When you decide to charge ₹29 per month

1. In Google Play Console, create an auto-renewing monthly subscription with the exact product ID `fintab_premium_monthly_29`.
2. Set its India price to ₹29 per month and complete the Play payments profile and bank-account setup.
3. Add server-side purchase verification and entitlement handling before accepting real payments.
4. Test the subscription through a Play internal testing track with license testers.
5. Only after testing, change this line in `lib/main.dart`:

```dart
const premiumSubscriptionsEnabled = true;
```

6. Build and publish a new app version. Existing V3.4 users remain free until they install that future release and choose to subscribe.

Do not collect UPI PINs, card details, passwords, or bank credentials inside FinTab. Google Play must handle subscription payment details.
