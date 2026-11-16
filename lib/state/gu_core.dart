/// Gujarati strings for the customer + admin core alignment pass (GST rate,
/// one-active coin rule, validation messages, staff promote, shop Gujarati
/// fields, coupon item targeting, return preview). Looked up by `gt`.
///
/// Register: `import 'gu_core.dart';` in `gu_strings.dart` and look up
/// `guCore[en]` next to `guFollowup[en]`.
const Map<String, String> guCore = {
  // Validators (lib/data/validators.dart)
  'Enter the mobile number': 'મોબાઇલ નંબર લખો',
  'Mobile number must be digits only': 'મોબાઇલ નંબરમાં ફક્ત અંકો હોવા જોઈએ',
  'Mobile number must be 10 digits': 'મોબાઇલ નંબર 10 અંકનો હોવો જોઈએ',
  'Mobile number must start with 6, 7, 8 or 9':
      'મોબાઇલ નંબર 6, 7, 8 અથવા 9 થી શરૂ થવો જોઈએ',
  'Enter the e-mail address': 'ઇમેઇલ સરનામું લખો',
  'E-mail is too long (254 characters at most)':
      'ઇમેઇલ ખૂબ લાંબો છે (વધુમાં વધુ 254 અક્ષર)',
  'Enter a valid e-mail address': 'સાચું ઇમેઇલ સરનામું લખો',
  'Enter the GSTIN': 'GSTIN લખો',
  'GSTIN must be 15 characters': 'GSTIN 15 અક્ષરનો હોવો જોઈએ',
  'Enter a valid GSTIN (for example 24ABCDE1234F1Z5)':
      'સાચો GSTIN લખો (ઉદા. 24ABCDE1234F1Z5)',
  'Enter the PAN': 'PAN લખો',
  'PAN must look like ABCDE1234F': 'PAN આવો હોવો જોઈએ: ABCDE1234F',
  'Enter the pincode': 'પિનકોડ લખો',
  'Pincode must be 6 digits': 'પિનકોડ 6 અંકનો હોવો જોઈએ',
  'Enter the IFSC code': 'IFSC કોડ લખો',
  'IFSC must be 11 characters, like HDFC0001234':
      'IFSC 11 અક્ષરનો હોવો જોઈએ, જેમ કે HDFC0001234',
  'Enter the UPI ID': 'UPI ID લખો',
  'Enter a valid UPI ID, like name@bank': 'સાચો UPI ID લખો, જેમ કે name@bank',
  'Enter the account number': 'ખાતા નંબર લખો',
  'Account number must be 9 to 18 digits': 'ખાતા નંબર 9 થી 18 અંકનો હોવો જોઈએ',
  'Choose a GST rate': 'GST દર પસંદ કરો',
  'GST rate must be 0, 3, 5, 12, 18 or 28':
      'GST દર 0, 3, 5, 12, 18 અથવા 28 હોવો જોઈએ',

  // Product edit (GST + HSN)
  'GST rate (included in the price)': 'GST દર (ભાવમાં સામેલ)',
  'HSN code must be 2 to 8 digits': 'HSN કોડ 2 થી 8 અંકનો હોવો જોઈએ',
  'Price must be between 0 and 10,00,000': 'ભાવ 0 થી 10,00,000 ની વચ્ચે હોવો જોઈએ',
  'MRP must be between 0 and 10,00,000': 'MRP 0 થી 10,00,000 ની વચ્ચે હોવો જોઈએ',
  'Price cannot be more than the MRP': 'ભાવ MRP કરતાં વધુ ન હોઈ શકે',
  'Stock cannot be negative': 'સ્ટોક ઋણ ન હોઈ શકે',

  // Coin rules
  'Switch on this rule?': 'આ નિયમ ચાલુ કરવો?',
  'Only one coin rule can be on at a time. This switches off':
      'એક સમયે ફક્ત એક જ સિક્કા નિયમ ચાલુ રહી શકે. આ બંધ કરશે',
  'Switch on': 'ચાલુ કરો',
  'Active (only one rule can be on)': 'ચાલુ (એક સમયે એક જ નિયમ)',
  'Use the date format yyyy-MM-dd': 'તારીખ yyyy-MM-dd રીતે લખો',
  'The end date must be after the start date':
      'અંતિમ તારીખ શરૂઆતની તારીખ પછીની હોવી જોઈએ',

  // Staff
  'Make this customer a cashier?': 'આ ગ્રાહકને કેશિયર બનાવવો?',
  'This e-mail already belongs to a customer. Make them a cashier? They keep their order history.':
      'આ ઇમેઇલ પહેલેથી ગ્રાહકનો છે. તેમને કેશિયર બનાવવા છે? તેમનો ઓર્ડર ઇતિહાસ રહેશે.',
  'Make cashier': 'કેશિયર બનાવો',

  // Shop settings
  'Gujarati texts and short name': 'ગુજરાતી લખાણ અને ટૂંકું નામ',
  'Shown when the app is in Gujarati. Leave blank to show the English text.':
      'એપ ગુજરાતીમાં હોય ત્યારે બતાવાશે. ખાલી હોય તો અંગ્રેજી લખાણ બતાવાશે.',
  'Short name (tight spaces)': 'ટૂંકું નામ (ઓછી જગ્યા માટે)',
  'Shop name (Gujarati)': 'દુકાનનું નામ (ગુજરાતી)',
  'Address (Gujarati)': 'સરનામું (ગુજરાતી)',
  'Tagline (Gujarati)': 'ટેગલાઇન (ગુજરાતી)',
  'Shop details (Gujarati)': 'દુકાનની વિગત (ગુજરાતી)',
  'State code must be 2 digits (for example 24)':
      'રાજ્ય કોડ 2 અંકનો હોવો જોઈએ (ઉદા. 24)',
  'Invoice prefix: up to 10 letters, digits or dashes':
      'ઇન્વૉઇસ ઉપસર્ગ: વધુમાં વધુ 10 અક્ષર, અંક કે ડેશ',
  'Weighed prefix must be 1 or 2 digits': 'વજન ઉપસર્ગ 1 કે 2 અંકનો હોવો જોઈએ',
  'WhatsApp number must be 10 to 15 digits':
      'WhatsApp નંબર 10 થી 15 અંકનો હોવો જોઈએ',
  'Enter a full link starting with https://':
      'https:// થી શરૂ થતી પૂરી લિંક લખો',
  'App icon ready (192 and 512 px). Replacing the logo makes new icons.':
      'એપ આઇકન તૈયાર છે (192 અને 512 px). લોગો બદલતાં નવા આઇકન બનશે.',

  // Config screen
  'Enter a whole number': 'પૂર્ણ સંખ્યા લખો',
  'Must be at least': 'ઓછામાં ઓછું',
  'Must be at most': 'વધુમાં વધુ',
  'Too long (500 characters at most)': 'ખૂબ લાંબું (વધુમાં વધુ 500 અક્ષર)',
  'Pick the id of a money account (a UUID) or leave blank':
      'પૈસા ખાતાનો id (UUID) લખો અથવા ખાલી રાખો',
  'Sender id is at most 11 characters': 'સેન્ડર id વધુમાં વધુ 11 અક્ષરનો',

  // Credit
  'This customer is blocked: no credit sales until they are unblocked.':
      'આ ગ્રાહક બ્લૉક છે: અનબ્લૉક થાય ત્યાં સુધી ઉધાર વેચાણ નહીં.',

  // Coupons
  'Specific items': 'ખાસ વસ્તુઓ',
  'Specific items (optional)': 'ખાસ વસ્તુઓ (વૈકલ્પિક)',
  'Any item in the chosen categories': 'પસંદ કરેલી શ્રેણીની કોઈ પણ વસ્તુ',
  'Limit the coupon to chosen packs or whole products':
      'કૂપન પસંદ કરેલા પૅક અથવા આખી પ્રોડક્ટ સુધી મર્યાદિત કરો',
  'Search items': 'વસ્તુ શોધો',
  'Name of the product': 'પ્રોડક્ટનું નામ',
  'No items found.': 'કોઈ વસ્તુ મળી નથી.',
  'This pack': 'આ પૅક',
  'this pack': 'આ પૅક',
  'All packs': 'બધા પૅક',
  'all packs': 'બધા પૅક',
  'No specific items': 'કોઈ ખાસ વસ્તુ નહીં',
  'Use': 'વાપરો',
  'selected': 'પસંદ કરેલ',
  'Could not load the items. Try again.': 'વસ્તુઓ લોડ ન થઈ. ફરી પ્રયત્ન કરો.',
  'Enter the coupon code': 'કૂપન કોડ લખો',
  'Use 3 to 16 letters or numbers': '3 થી 16 અક્ષર કે અંક વાપરો',
  'Pick categories, single packs or whole products. The discount is shared over the covered lines only, and the minimum order counts them only.':
      'શ્રેણી, એકલા પૅક કે આખી પ્રોડક્ટ પસંદ કરો. છૂટ ફક્ત આવરી લીધેલી લાઇનો પર વહેંચાય છે અને ન્યૂનતમ ઓર્ડરમાં ફક્ત એ જ ગણાય છે.',

  // Orders return preview
  'Refund preview': 'રિફંડનું પૂર્વાવલોકન',
  'Coupon share not refunded': 'કૂપનનો હિસ્સો રિફંડ થતો નથી',
  'Coin share not refunded': 'સિક્કાનો હિસ્સો રિફંડ થતો નથી',
  'Coupon taken back (kept items fall below the minimum)':
      'કૂપન પાછો લીધો (રાખેલી વસ્તુઓ ન્યૂનતમથી ઓછી)',
  'Delivery fee refunded': 'ડિલિવરી ફી પરત',
  'Customer is refunded': 'ગ્રાહકને રિફંડ',

  // Flash
  'Sale deleted': 'સેલ કાઢી નાખ્યો',
  'Delete this sale?': 'આ સેલ કાઢી નાખવો?',
  'Delete sale': 'સેલ કાઢી નાખો',
};
