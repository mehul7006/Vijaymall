/// Gujarati strings added by the reports / credit / stock / counter-desk audit
/// (doc 30): period ranges, audit-log filters, stock count, stock movement
/// export, shop settings and the product POS editor (looked up by `gt`).
const Map<String, String> kGuAuditFix = {
  // period range picker
  'Custom': 'કસ્ટમ',
  'From (yyyy-MM-dd)': 'ક્યારથી (yyyy-MM-dd)',
  'To (optional)': 'ક્યાં સુધી (વૈકલ્પિક)',
  'today': 'આજ',
  'Show range': 'સમયગાળો બતાવો',
  'Both days are included. At most 366 days. Without a start date the period above is used.':
      'બંને દિવસો ગણાય છે. વધુમાં વધુ 366 દિવસ. શરૂઆતની તારીખ વિના ઉપરનો સમયગાળો વપરાય છે.',
  'Enter the start date (yyyy-MM-dd)': 'શરૂઆતની તારીખ લખો (yyyy-MM-dd)',
  'Use the format yyyy-MM-dd': 'yyyy-MM-dd ફોર્મેટ વાપરો',
  'The end date cannot be before the start date':
      'અંતિમ તારીખ શરૂઆતની તારીખ પહેલાં ન હોઈ શકે',
  'The range is limited to 366 days': 'સમયગાળો વધુમાં વધુ 366 દિવસનો હોઈ શકે',
  'The range is limited to 93 days': 'સમયગાળો વધુમાં વધુ 93 દિવસનો હોઈ શકે',
  // counter desk
  'All cashiers': 'બધા કેશિયર',
  'Show': 'બતાવો',
  'OPEN': 'ખુલ્લી',
  'Closed': 'બંધ',
  'bills': 'બિલ',
  'shifts': 'શિફ્ટ',
  'Discounts': 'ડિસ્કાઉન્ટ',
  'Returns': 'રિટર્ન',
  'Drawer': 'ગલ્લો',
  'System': 'સિસ્ટમ',
  'Product': 'પ્રોડક્ટ',
  'Action': 'ક્રિયા',
  'Record kind': 'રેકોર્ડનો પ્રકાર',
  'Record id (optional)': 'રેકોર્ડ આઈડી (વૈકલ્પિક)',
  'Paste the id of a bill, shift, purchase...':
      'બિલ, શિફ્ટ, ખરીદીનો આઈડી પેસ્ટ કરો...',
  'To (yyyy-MM-dd)': 'ક્યાં સુધી (yyyy-MM-dd)',
  'With both dates the range is limited to 93 days.':
      'બંને તારીખો સાથે સમયગાળો વધુમાં વધુ 93 દિવસનો હોય છે.',
  'products at or below their alert level, emptiest first':
      'એલર્ટ સ્તરે કે તેનાથી ઓછા સ્ટોકવાળી પ્રોડક્ટ, સૌથી ખાલી પહેલાં',
  'Only the 200 emptiest products can be listed. Restock these first, then reopen the list.':
      'ફક્ત સૌથી ખાલી 200 પ્રોડક્ટ બતાવી શકાય છે. પહેલાં આ ભરો, પછી યાદી ફરી ખોલો.',
  'There may be more. Choose a larger number above.':
      'વધુ હોઈ શકે છે. ઉપર મોટો આંકડો પસંદ કરો.',
  'Put these goods back on sale?': 'આ માલ ફરી વેચાણમાં મૂકવો છે?',
  'Confirm these goods as defective?': 'આ માલ ખામીવાળો તરીકે નક્કી કરવો છે?',
  'This computer clock differs from the server by several minutes. Offline bills can be refused until it is corrected.':
      'આ કમ્પ્યુટરની ઘડિયાળ સર્વરથી કેટલીક મિનિટ અલગ છે. સુધારો ન થાય ત્યાં સુધી ઓફલાઇન બિલ નામંજૂર થઈ શકે.',
  // stock count
  'Enter a counted quantity (0 or more) for every product.':
      'દરેક પ્રોડક્ટ માટે ગણેલી સંખ્યા (0 કે વધુ) લખો.',
  'This count was already saved with different figures. Check the list and save again.':
      'આ ગણતરી અલગ આંકડા સાથે પહેલાં સેવ થઈ ગઈ છે. યાદી તપાસી ફરી સેવ કરો.',
  'Every counted product matched the system. Nothing was changed.':
      'ગણેલી દરેક પ્રોડક્ટ સિસ્ટમ સાથે મળી. કંઈ બદલાયું નથી.',
  'A stock count can have 500 products at most.':
      'એક સ્ટોક ગણતરીમાં વધુમાં વધુ 500 પ્રોડક્ટ હોઈ શકે.',
  // stock movement report
  'Only the newest movements are loaded, so this day may be incomplete. Load older movements to cover it.':
      'ફક્ત નવી હિલચાલ લોડ થઈ છે, તેથી આ દિવસ અધૂરો હોઈ શકે. તેને આવરી લેવા જૂની હિલચાલ લોડ કરો.',
  'Load older movements': 'જૂની હિલચાલ લોડ કરો',
  'Could not load older movements': 'જૂની હિલચાલ લોડ થઈ નહીં',
  'Stock movement report downloaded': 'સ્ટોક હિલચાલ રિપોર્ટ ડાઉનલોડ થયો',
  'Download is only available in the browser':
      'ડાઉનલોડ ફક્ત બ્રાઉઝરમાં ઉપલબ્ધ છે',
  // shop settings
  'Invoice prefix: 2 to 6 capital letters or digits':
      'ઇનવોઇસ પ્રિફિક્સ: 2 થી 6 કેપિટલ અક્ષર કે અંક',
  'Enter a valid UPI ID, like name@bank': 'માન્ય UPI આઈડી લખો, જેમ કે name@bank',
  'Changing the prefix affects only new invoice numbers. Blank keeps VSM.':
      'પ્રિફિક્સ બદલવાથી ફક્ત નવા ઇનવોઇસ નંબર પર અસર થાય છે. ખાલી રાખો તો VSM રહેશે.',
  'You changed how scale labels are read. Reprint the scale labels after saving.':
      'સ્કેલ લેબલ કેવી રીતે વંચાય તે તમે બદલ્યું. સેવ કર્યા પછી સ્કેલ લેબલ ફરી છાપો.',
  // product POS editor
  'PLU (required)': 'PLU (જરૂરી)',
  'Weighed item code, 1 to 6 digits': 'તોલ વસ્તુનો કોડ, 1 થી 6 અંક',
  'PLU must be 1 to 6 digits': 'PLU 1 થી 6 અંકનો હોવો જોઈએ',
  'Enter the item code (PLU) of this weighed item':
      'આ તોલ વસ્તુનો આઈટમ કોડ (PLU) લખો',
  'Another product already uses this PLU': 'આ PLU બીજી પ્રોડક્ટ વાપરે છે',
  'This barcode is already on another product':
      'આ બારકોડ બીજી પ્રોડક્ટ પર છે',
  'A weighed item is counter-only. Its price is per 1000 g and its stock is kept in grams (set both in the catalog). Do not give it a 13-digit barcode that starts with the shop\'s weighed prefix.':
      'તોલ વસ્તુ ફક્ત કાઉન્ટર પર વેચાય છે. તેનો ભાવ 1000 ગ્રામ દીઠ અને સ્ટોક ગ્રામમાં રહે છે (બંને કેટલોગમાં નક્કી કરો). દુકાનના તોલ પ્રિફિક્સથી શરૂ થતો 13 અંકનો બારકોડ ન આપો.',
};
