/// Gujarati strings for the cashier till: card/UPI machine, payment channels,
/// credit picker, return preview, GST by slab, lot notices (looked up by `gt`).
const Map<String, String> guCounter = {
  // machine dialog
  'Card / UPI machine (manual)': 'કાર્ડ / UPI મશીન (મેન્યુઅલ)',
  'Card / UPI machine': 'કાર્ડ / UPI મશીન',
  'This machine already has a payment open. Resume it, or use another channel.':
      'આ મશીન પર પેમેન્ટ ખુલ્લું છે. તેને ચાલુ રાખો અથવા બીજી ચેનલ વાપરો.',
  'That payment reference was used for another amount or machine. Press Try again to use a new one.':
      'આ રેફરન્સ બીજી રકમ કે મશીન માટે વપરાયો છે. નવો વાપરવા ફરી પ્રયત્ન દબાવો.',
  'Press Try again to start a new payment.': 'નવું પેમેન્ટ શરૂ કરવા ફરી પ્રયત્ન દબાવો.',
  'This machine is not set up on the server. Close this and take the payment with a typed reference instead, or ask an admin.':
      'આ મશીન સર્વર પર સેટ નથી. બંધ કરીને રેફરન્સ લખીને પેમેન્ટ લો, અથવા એડમિનને પૂછો.',
  'Too many card payments in a minute. Wait a little and try again.':
      'એક મિનિટમાં ઘણાં કાર્ડ પેમેન્ટ. થોડી રાહ જોઈ ફરી પ્રયત્ન કરો.',
  'Could not open that payment.': 'તે પેમેન્ટ ખોલી શકાયું નહીં.',
  'This machine confirms by itself: wait for the result.':
      'આ મશીન જાતે કન્ફર્મ કરે છે: પરિણામની રાહ જુઓ.',
  'This payment is already cancelled or declined. Start a new one.':
      'આ પેમેન્ટ રદ અથવા નામંજૂર થઈ ગયું છે. નવું શરૂ કરો.',
  'Could not confirm.': 'કન્ફર્મ થઈ શક્યું નહીં.',
  'Press Cancel on the machine. This payment closes by itself once the machine reports it.':
      'મશીન પર રદ દબાવો. મશીન જણાવે ત્યારે આ પેમેન્ટ જાતે બંધ થઈ જશે.',
  'The customer has already paid. Use this payment, or void it today.':
      'ગ્રાહકે ચૂકવી દીધું છે. આ પેમેન્ટ વાપરો અથવા આજે જ રદ કરો.',
  'Could not cancel.': 'રદ થઈ શક્યું નહીં.',
  'Payment voided': 'પેમેન્ટ રદ થયું',
  'This payment cannot be voided here (not paid, or a manual machine). Refund it on the machine.':
      'આ પેમેન્ટ અહીંથી રદ થઈ શકતું નથી (ચૂકવાયું નથી, અથવા મેન્યુઅલ મશીન). મશીન પર રિફંડ કરો.',
  'A bill already uses this payment. Return the bill instead.':
      'આ પેમેન્ટ કોઈ બિલ પર વપરાયેલું છે. બિલ પરત કરો.',
  'Refund it from the Paytm dashboard instead.': 'તેના બદલે Paytm ડેશબોર્ડથી રિફંડ કરો.',
  'The void result is unknown. Check the machine before trying again; this payment cannot go on a bill meanwhile.':
      'રદ કરવાનું પરિણામ ખબર નથી. ફરી પ્રયત્ન પહેલાં મશીન તપાસો; ત્યાં સુધી આ પેમેન્ટ બિલ પર નહીં જાય.',
  'Could not void.': 'રદ થઈ શક્યું નહીં.',
  'Resume the open payment': 'ખુલ્લું પેમેન્ટ ચાલુ રાખો',
  'Connection lost. Still waiting: this payment is kept and checked again. Do not start another one.':
      'કનેક્શન ગયું. રાહ જુઓ: આ પેમેન્ટ સાચવેલું છે અને ફરી તપાસાશે. બીજું શરૂ ન કરો.',
  'Machine': 'મશીન',
  'Paid by': 'ચુકવણી રીત',
  'Reference': 'રેફરન્સ',
  'This payment is already on a bill.': 'આ પેમેન્ટ પહેલેથી બિલ પર છે.',
  'Use this payment on the bill': 'આ પેમેન્ટ બિલ પર વાપરો',
  'Void this payment (customer left)': 'આ પેમેન્ટ રદ કરો (ગ્રાહક જતા રહ્યા)',
  'Charge the customer on the bank machine, then type the approval code below.':
      'બેંક મશીન પર ગ્રાહક પાસેથી લો, પછી નીચે એપ્રુવલ કોડ લખો.',
  'Waiting for the customer to pay on the machine...': 'ગ્રાહક મશીન પર ચૂકવે તેની રાહ જોઈ રહ્યા છીએ...',
  'From the machine slip': 'મશીનની સ્લિપ પરથી',
  'RRN (optional)': 'RRN (વૈકલ્પિક)',
  'Confirm payment taken': 'પેમેન્ટ લીધું તે કન્ફર્મ કરો',
  'Check now': 'હમણાં તપાસો',
  'Cancel this payment': 'આ પેમેન્ટ રદ કરો',
  'The payment was declined.': 'પેમેન્ટ નામંજૂર થયું.',
  'The payment was voided.': 'પેમેન્ટ રદ કરાયું.',
  'The payment was cancelled.': 'પેમેન્ટ રદ થયું.',
  'The payment timed out.': 'પેમેન્ટનો સમય પૂરો થયો.',
  'A late payment can still arrive for a while. Check the machine and press Check again before taking money from this customer another way.':
      'મોડું પેમેન્ટ હજી થોડા સમય સુધી આવી શકે છે. આ ગ્રાહક પાસેથી બીજી રીતે પૈસા લેતા પહેલાં મશીન તપાસો અને ફરી તપાસો દબાવો.',
  'Check again': 'ફરી તપાસો',
  'Try again with a new payment': 'નવા પેમેન્ટ સાથે ફરી પ્રયત્ન કરો',
  'Money goes to': 'પૈસા અહીં જાય છે',
  'Machine payment received': 'મશીન પેમેન્ટ મળ્યું',
  'Press Charge to put it on the bill.': 'બિલ પર મૂકવા ચાર્જ દબાવો.',
  'Waiting for the machine payment of': 'મશીન પેમેન્ટની રાહ:',
  'Open machine payment': 'મશીન પેમેન્ટ ખોલો',
  'Charge on bank machine': 'બેંક મશીન પર ચાર્જ કરો',
  'Take on card machine': 'કાર્ડ મશીન પર લો',
  'Needs the internet. Without it, type the slip reference below instead.':
      'ઇન્ટરનેટ જોઈએ. ન હોય તો નીચે સ્લિપનો રેફરન્સ લખો.',
  'Add items and wait for the price first': 'પહેલા વસ્તુઓ ઉમેરો અને ભાવની રાહ જુઓ',
  'The machine amount must be between Rs 0.01 and the amount still due':
      'મશીનની રકમ Rs 0.01 થી બાકી રકમ વચ્ચે હોવી જોઈએ',
  'Machine payment ready. Press Charge to put it on the bill.':
      'મશીન પેમેન્ટ તૈયાર. બિલ પર મૂકવા ચાર્જ દબાવો.',
  'A card/UPI machine payment is waiting on this bill. Use it, cancel it or void it first.':
      'આ બિલ પર કાર્ડ/UPI મશીન પેમેન્ટ બાકી છે. પહેલા તેને વાપરો, રદ કરો અથવા વોઇડ કરો.',
  'The machine payment is still open. Finish, cancel or void it first.':
      'મશીન પેમેન્ટ હજી ખુલ્લું છે. પહેલા પૂરું કરો, રદ કરો અથવા વોઇડ કરો.',
  'The machine payment of': 'મશીન પેમેન્ટ',
  'is more than the': 'આના કરતાં વધુ છે:',
  'still due': 'બાકી',
  'A machine payment of': 'મશીન પેમેન્ટ',
  'is waiting. Choose Card/UPI to put it on the bill, or open it and void it.':
      'બાકી છે. બિલ પર મૂકવા કાર્ડ/UPI પસંદ કરો, અથવા ખોલીને વોઇડ કરો.',
  'The card/UPI machine payment is not confirmed as paid yet. Open it and wait for the result, or choose another way.':
      'કાર્ડ/UPI મશીન પેમેન્ટ હજી ચૂકવાયેલું કન્ફર્મ નથી. ખોલીને પરિણામની રાહ જુઓ, અથવા બીજી રીત પસંદ કરો.',
  'That machine payment is already on another bill. Take the payment again.':
      'તે મશીન પેમેન્ટ બીજા બિલ પર વપરાયું છે. ફરી પેમેન્ટ લો.',
  'The card/UPI line must be exactly the machine payment amount. Split the payment so that line matches.':
      'કાર્ડ/UPI લાઇન મશીન પેમેન્ટની રકમ જેટલી જ હોવી જોઈએ. પેમેન્ટ વહેંચો.',
  'The machine payment was taken by the other method (UPI vs card). Choose the matching payment method.':
      'મશીન પેમેન્ટ બીજી રીતે (UPI/કાર્ડ) લેવાયું હતું. યોગ્ય ચુકવણી રીત પસંદ કરો.',
  'Too many tries. Ask the manager to sign in.': 'ઘણા પ્રયત્નો. મેનેજરને સાઇન ઇન કરવા કહો.',
  'That coupon cannot be used.': 'તે કૂપન વાપરી શકાતું નથી.',
  'more to use it.': 'વધુ ઉમેરો તો વાપરી શકાશે.',
  // channels
  'Choose which': 'પસંદ કરો કયી',
  'channel the money goes to': 'ચેનલમાં પૈસા જશે',
  'Reference must be 100 characters or fewer': 'રેફરન્સ વધુમાં વધુ 100 અક્ષર',
  'The payments add up to': 'ચુકવણીઓનો સરવાળો',
  'but the bill is': 'પણ બિલ છે',
  'Use “Split this payment” to add the part already taken, then pay the rest.':
      '“આ ચુકવણી વહેંચો” થી લીધેલો ભાગ ઉમેરો, પછી બાકી ચૂકવો.',
  // GST
  'GST by slab (estimate; the bill total is exact)':
      'સ્લેબ મુજબ GST (અંદાજ; બિલનો કુલ ચોક્કસ છે)',
  'GST by slab': 'સ્લેબ મુજબ GST',
  'Rate': 'દર',
  'Taxable': 'કરપાત્ર',
  'Total': 'કુલ',
  // return preview
  'Tick at least one item to refund, then press Check refund.':
      'રિફંડ માટે ઓછામાં ઓછી એક વસ્તુ ટિક કરો, પછી રિફંડ તપાસો દબાવો.',
  'Could not work out the refund.': 'રિફંડની ગણતરી થઈ શકી નહીં.',
  'Same as bill': 'બિલ મુજબ',
  'Check refund': 'રિફંડ તપાસો',
  'Confirm refund': 'રિફંડ કન્ફર્મ કરો',
  'Refund worked out by the server': 'સર્વરે ગણેલું રિફંડ',
  'Price of returned units': 'પરત થયેલા નંગની કિંમત',
  'Coupon share (leaves with the units)': 'કૂપનનો ભાગ (નંગ સાથે જાય છે)',
  'Coins / discount share': 'કોઇન / ડિસ્કાઉન્ટનો ભાગ',
  'Coupon taken back': 'કૂપન પાછું લેવાયું',
  'Refund for this line': 'આ લાઇનનું રિફંડ',
  'Coupon taken back from this refund': 'આ રિફંડમાંથી કૂપન પાછું લેવાયું',
  'Coupon policy': 'કૂપન નીતિ',
  'GST in refund': 'રિફંડમાં GST',
  'taxable': 'કરપાત્ર',
  'Total refund': 'કુલ રિફંડ',
  'Coins taken back or restored, and any part set against udhar, are shown after the refund is confirmed.':
      'પાછા લેવાયેલા/પાછા અપાયેલા કોઇન અને ઉધારમાં સરભર થયેલો ભાગ રિફંડ કન્ફર્મ થયા પછી દેખાશે.',
  // credit picker
  'This customer is blocked, so credit cannot be given.':
      'આ ગ્રાહક બ્લોક છે, તેથી ઉધાર આપી શકાતું નથી.',
  'Type at least 2 letters to search all customers.': 'બધા ગ્રાહકો શોધવા ઓછામાં ઓછા 2 અક્ષર લખો.',
  'Could not load credit customers.': 'ઉધાર ગ્રાહકો લોડ થઈ શક્યા નહીં.',
  'Credit is not enabled for this customer. An admin must set a credit limit first.':
      'આ ગ્રાહક માટે ઉધાર ચાલુ નથી. પહેલા એડમિને ઉધાર મર્યાદા મૂકવી પડશે.',
  'This does not match': 'આ મેળ ખાતું નથી',
  'With credit': 'ઉધાર સાથે',
  'All customers': 'બધા ગ્રાહકો',
  'No customer has credit yet. Type a mobile number to check one.':
      'હજી કોઈ ગ્રાહકને ઉધાર નથી. તપાસવા મોબાઇલ નંબર લખો.',
  'No credit customer matches that. Type the full 10-digit mobile to check it.':
      'એવો કોઈ ઉધાર ગ્રાહક નથી. તપાસવા પૂરો 10 અંકનો મોબાઇલ લખો.',
  'Credit not enabled': 'ઉધાર ચાલુ નથી',
  'Type the full mobile of': 'પૂરો મોબાઇલ લખો:',
  'Use this customer': 'આ ગ્રાહક વાપરો',
  'Credit is not enabled for this customer (no credit limit is set). Use “Enable credit” in the Payment box, or ask an admin.':
      'આ ગ્રાહક માટે ઉધાર ચાલુ નથી (ઉધાર મર્યાદા નથી). ચુકવણી બોક્સમાં “ઉધાર ચાલુ કરો” વાપરો અથવા એડમિનને પૂછો.',
  'This customer is blocked, so credit cannot be given. Take the money another way.':
      'આ ગ્રાહક બ્લોક છે, ઉધાર આપી શકાતું નથી. બીજી રીતે પૈસા લો.',
  // lots / added wording
  'After': 'પછી',
  'more the price is': 'વધુ નંગ પછી ભાવ',
  'added': 'ઉમેર્યું',
  'Most you can bill on one line is': 'એક લાઇનમાં વધુમાં વધુ બિલ કરી શકાય:',
  'Weight': 'વજન',
  'No product found for': 'કોઈ વસ્તુ મળી નહીં:',
  'Check the barcode or search by name.': 'બારકોડ તપાસો અથવા નામથી શોધો.',
  // inputs
  'A coupon code is at most 30 characters.': 'કૂપન કોડ વધુમાં વધુ 30 અક્ષરનો હોય.',
  'Cash received': 'મળેલી રોકડ',
  'PIN must be 4 to 8 digits': 'PIN 4 થી 8 અંકનો હોવો જોઈએ',
  'The reason must be 100 characters or fewer.': 'કારણ વધુમાં વધુ 100 અક્ષરનું હોય.',
  // holds
  'Removed automatically on': 'આ દિવસે જાતે દૂર થશે:',
  'Discount approved by': 'ડિસ્કાઉન્ટ મંજૂર કરનાર:',
  'Paid': 'ચૂકવ્યું',
  // redesigned till labels
  'Checking shift…': 'શિફ્ટ તપાસી રહ્યા છીએ…',
  'No shift open': 'શિફ્ટ ખુલ્લી નથી',
  'Shift open': 'શિફ્ટ ખુલ્લી',
  'since': 'થી',
  'float': 'ફ્લોટ',
  'Start shift': 'શિફ્ટ શરૂ કરો',
  'Scan barcode or type a name, then press Enter': 'બારકોડ સ્કેન કરો અથવા નામ લખી Enter દબાવો',
  'Sold by weight': 'વજનથી વેચાય',
  'No GST': 'GST નથી',
  'GST': 'GST',
  'per kg': 'પ્રતિ કિલો',
  'Scan a barcode or type a name and press Enter. Tap a product to add it; weighed items ask for the weight.':
      'બારકોડ સ્કેન કરો અથવા નામ લખી Enter દબાવો. ઉમેરવા વસ્તુ પર ટેપ કરો; વજનવાળી વસ્તુ વજન પૂછશે.',
  'Current bill': 'હાલનું બિલ',
  'Hold': 'હોલ્ડ',
  'Held': 'હોલ્ડ પર',
  '10-digit number for coins or credit': 'કોઇન કે ઉધાર માટે 10 અંકનો નંબર',
  'Optional': 'વૈકલ્પિક',
  'Scan an item or tap a product to start': 'શરૂ કરવા વસ્તુ સ્કેન કરો અથવા વસ્તુ પર ટેપ કરો',
  'Subtotal': 'પેટા કુલ',
  'manual': 'મેન્યુઅલ',
  'Round-off': 'રાઉન્ડ-ઓફ',
  'Still due': 'હજી બાકી',
  'To pay': 'ચૂકવવાના',
  'UPI txn / last 4': 'UPI વ્યવહાર / છેલ્લા 4',
  'Pricing…': 'ભાવ ગણી રહ્યા છીએ…',
  'Charge': 'ચાર્જ',
  'Find old bill / Return': 'જૂનું બિલ શોધો / પરત',
  'Take credit repayment': 'ઉધાર ભરપાઈ લો',
  'Today’s totals': 'આજના કુલ',
  'credit available': 'ઉધાર ઉપલબ્ધ',
  'credit not enabled': 'ઉધાર ચાલુ નથી',
  'coins': 'કોઇન',
  'New customer. They will earn coins on this bill.': 'નવા ગ્રાહક. આ બિલ પર તેમને કોઇન મળશે.',
  'Change discount': 'ડિસ્કાઉન્ટ બદલો',
  'Give a discount': 'ડિસ્કાઉન્ટ આપો',
  'e.g. damaged pack': 'દા.ત. ખરાબ પેક',
  'Manager PIN (optional for admins)': 'મેનેજર PIN (એડમિન માટે વૈકલ્પિક)',
  'Manager PIN (4–8 digits, asked from cashiers)': 'મેનેજર PIN (4–8 અંક, કેશિયર પાસે મંગાય છે)',
  'Ask a manager to enter their PIN': 'મેનેજરને PIN નાખવા કહો',
  'Apply discount': 'ડિસ્કાઉન્ટ લાગુ કરો',
  'A reason is needed for every discount.': 'દરેક ડિસ્કાઉન્ટ માટે કારણ જોઈએ.',
  'Ask a manager to enter their PIN (4–8 digits).': 'મેનેજરને PIN (4–8 અંક) નાખવા કહો.',
  'Udhar': 'ઉધાર',
  'Exact': 'બરાબર',
  'Cash received (₹)': 'મળેલી રોકડ (₹)',
  'Give change': 'પરત આપો',
  'Short by': 'ઓછા',
  'UPI QR for': 'UPI QR:',
  'shows here for the customer to scan.': 'અહીં ગ્રાહકને સ્કેન કરવા માટે દેખાશે.',
  'Show UPI link for': 'UPI લિંક બતાવો:',
  'Hide split payment': 'વહેંચેલી ચુકવણી છુપાવો',
  'Split this payment': 'આ ચુકવણી વહેંચો',
  'Pick a payment method above, type how much of the bill it covers, then add it. The rest is charged with the method you pick last.':
      'ઉપરથી ચુકવણી રીત પસંદ કરો, તે બિલનો કેટલો ભાગ ભરે તે લખો, પછી ઉમેરો. બાકી તમે છેલ્લે પસંદ કરેલી રીતથી લેવાશે.',
  'this': 'આ',
  'as a split line': 'વહેંચેલી લાઇન તરીકે',
  'Udhar (credit)': 'ઉધાર',
  'Split payment': 'વહેંચેલી ચુકવણી',
  'Print receipt (58 mm)': 'રસીદ છાપો (58 mm)',
  'Start next sale': 'આગલું વેચાણ શરૂ કરો',
  'each': 'દરેક',
  'Less': 'ઓછું',
};
