/// Product illustration library — port of assets/icons.js `art(key)`.
///
/// Each entry is the exact 140×140 SVG from the design handoff.
class ProductArt {
  ProductArt._();

  static String svg(String key) {
    switch (key) {
      case 'almonds':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="123" rx="34" ry="6" fill="rgba(110,70,18,.12)"/>
<ellipse cx="57" cy="38" rx="9.5" ry="14" transform="rotate(-28 57 38)" fill="#E8C084" stroke="#B57625" stroke-width="2.2"/>
<ellipse cx="78" cy="29" rx="8.5" ry="12.5" transform="rotate(24 78 29)" fill="#F2D5A8" stroke="#B57625" stroke-width="2.2"/>
<path d="M43 58c0-4 2.7-6.5 6.5-6.5h41c3.8 0 6.5 2.5 6.5 6.5l6.2 51.5c.5 4.2-2.7 7.5-6.9 7.5H43.7c-4.2 0-7.4-3.3-6.9-7.5L43 58Z" fill="#CB8B3A"/>
<path d="M46 51.5h48l-2.4 17H48.4L46 51.5Z" fill="#B57625"/>
<rect x="52" y="79" width="36" height="29" rx="9" fill="#FCEBC6"/>
<ellipse cx="63" cy="93" rx="5.6" ry="7.5" transform="rotate(-24 63 93)" fill="#B57625"/>
<ellipse cx="77" cy="93" rx="5.6" ry="7.5" transform="rotate(24 77 93)" fill="#D49A49"/>
</svg>''';
      case 'rice':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="123" rx="34" ry="6" fill="rgba(55,60,120,.12)"/>
<path d="M42 36c0-5 4-9 9-9h38c5 0 9 4 9 9v76c0 7-5 12-12 12H54c-7 0-12-5-12-12V36Z" fill="#FCFBFF"/>
<path d="M42 33h56v15H42z" fill="#C72433"/>
<path d="M42 33c0-3.3 2.7-6 6-6h44c3.3 0 6 2.7 6 6v5H42v-5Z" fill="#B3121C"/>
<path d="M35 52c11 4 59 4 70 0" stroke="#E1DFF4" stroke-width="2.5"/>
<ellipse cx="70" cy="84" rx="22" ry="18" fill="#F5D46F"/>
<ellipse cx="70" cy="80" rx="18" ry="13" fill="#FFE9A8"/>
<path d="M56 85c4 7 24 8 29 0" stroke="#B57625" stroke-width="2.4" stroke-linecap="round"/>
<path d="M62 74c5 2 11 2 16 0" stroke="#B57625" stroke-width="2.4" stroke-linecap="round"/>
<path d="M58 103c8 2 17 2 24 0" stroke="#E1DFF4" stroke-width="4" stroke-linecap="round"/>
</svg>''';
      case 'cream':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="33" ry="6" fill="rgba(150,50,90,.12)"/>
<rect x="45" y="31" width="50" height="17" rx="7" fill="#E8AA2E"/>
<rect x="50" y="28" width="40" height="11" rx="5.5" fill="#F5C95B"/>
<path d="M46 47h48c4.5 0 8 3.5 8 8v55c0 6.6-5.4 12-12 12H50c-6.6 0-12-5.4-12-12V55c0-4.5 3.5-8 8-8Z" fill="#F7BBD1"/>
<rect x="47" y="65" width="46" height="34" rx="12" fill="#FCD9E5"/>
<path d="M61 84c3.5 4 14.5 4 18 0" stroke="#C4567E" stroke-width="2.6" stroke-linecap="round"/>
<circle cx="58" cy="76" r="2.4" fill="#C4567E"/>
<circle cx="82" cy="76" r="2.4" fill="#C4567E"/>
<path d="M54 55c4-2 9-2 13 0" stroke="rgba(255,255,255,.85)" stroke-width="4" stroke-linecap="round"/>
</svg>''';
      case 'kulfi':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="28" ry="5.5" fill="rgba(40,120,140,.12)"/>
<path d="M57 81h26l-11 39c-.6 2.2-3.4 2.2-4 0L57 81Z" fill="#E0A459"/>
<path d="m64 88 2 20M72 88l-2 20M60 102h20" stroke="#C58A43" stroke-width="2" stroke-linecap="round"/>
<circle cx="59" cy="75" r="17" fill="#F5A9C4"/>
<circle cx="81" cy="75" r="17" fill="#A9DDEC"/>
<circle cx="70" cy="55" r="18" fill="#FFF1D3"/>
<path d="M64 51c2-2.5 5-3.5 8-2.5" stroke="#E8C084" stroke-width="2.4" stroke-linecap="round"/>
<circle cx="70" cy="34" r="5" fill="#D3202B"/>
<path d="M70 29c0-4 2-6 5-7" stroke="#12875A" stroke-width="2.4" stroke-linecap="round"/>
</svg>''';
      case 'pickle':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="30" ry="5.5" fill="rgba(170,70,20,.12)"/>
<rect x="47" y="28" width="46" height="15" rx="6" fill="#B3121C"/>
<rect x="52" y="25" width="36" height="9" rx="4.5" fill="#D93C31"/>
<path d="M46 43h48c4.4 0 8 3.6 8 8v58c0 6-4.9 11-11 11H49c-6.1 0-11-5-11-11V51c0-4.4 3.6-8 8-8Z" fill="#E8853B"/>
<rect x="46" y="67" width="48" height="38" rx="9" fill="#FFF3DF"/>
<path d="M56 86h28M58 94h24" stroke="#C9692A" stroke-width="3" stroke-linecap="round"/>
<path d="M64 57c3-3 9-3 12 0" stroke="#FFD2A4" stroke-width="3" stroke-linecap="round"/>
<path d="M96 60c6-10 14-8 17-3-5 5-11 6-17 3Z" fill="#F5B301"/>
</svg>''';
      case 'tea':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="33" ry="6" fill="rgba(20,110,70,.12)"/>
<path d="M42 36c0-5 4-9 9-9h38c5 0 9 4 9 9v76c0 7-5 12-12 12H54c-7 0-12-5-12-12V36Z" fill="#DDEFE2"/>
<path d="M42 33h56v13H42z" fill="#12875A"/>
<path d="M42 33c0-3.3 2.7-6 6-6h44c3.3 0 6 2.7 6 6v5H42v-5Z" fill="#0E6B48"/>
<circle cx="70" cy="80" r="21" fill="#F8EBC6"/>
<path d="M58 80c0 7 5 12 12 12s12-5 12-12" fill="#8B5E2B"/>
<path d="M58 80h24" stroke="#8B5E2B" stroke-width="2.5"/>
<path d="M64 70c1.5-4 5-6 8-5.5" stroke="#12875A" stroke-width="2.4" stroke-linecap="round"/>
<path d="M76 64c5 2 8 6 8 9" stroke="#12875A" stroke-width="2.4" stroke-linecap="round"/>
<path d="M53 104c10 3 24 3 34 0" stroke="#C3E0CE" stroke-width="3" stroke-linecap="round"/>
</svg>''';
      case 'cashew':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="123" rx="34" ry="6" fill="rgba(120,80,20,.12)"/>
<path d="M43 56c0-4 3-7 7-7h40c4 0 7 3 7 7l6.2 53c.5 4.3-2.8 8-7.2 8H44c-4.4 0-7.7-3.7-7.2-8L43 56Z" fill="#D9A959"/>
<path d="M46 49.5h48l-2 14.5H48z" fill="#C08C3E"/>
<rect x="52" y="76" width="36" height="34" rx="10" fill="#FFF0D2"/>
<path d="M63 92c-3-5 1-11 6-10 5 1 7 7 3 11-2.6 2.5-7 1.8-9-1Z" fill="#C58A43"/>
<path d="M74 88c-1-5 4-9 8-7 4 2 4 8 0 10-3 1.5-6.5-.2-8-3Z" fill="#A56C2A"/>
<ellipse cx="60" cy="31" rx="8" ry="12" transform="rotate(-25 60 31)" fill="#F1D5A5" stroke="#B57625" stroke-width="2"/>
</svg>''';
      case 'oil':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="27" ry="5.5" fill="rgba(130,90,20,.12)"/>
<rect x="60" y="22" width="20" height="16" rx="4" fill="#12875A"/>
<path d="M63 37h14v10c0 4 8 8 10 16l6 43c.8 6-4 11.5-10 11.5H57c-6 0-10.8-5.5-10-11.5l6-43c2-8 10-12 10-16V37Z" fill="#E7BF5A"/>
<path d="M54 70c7-3 25-3 32 0l4 32H50l4-32Z" fill="#FCF2D4"/>
<path d="M61 86c2-6 10-9 15-5 4 3 3 9-1 12-5 3-12-1-14-7Z" fill="#12875A"/>
<path d="M70 76c-1 7 0 12 4 17" stroke="#DBEFE3" stroke-width="2" stroke-linecap="round"/>
<path d="M56 46c4-2 24-2 28 0" stroke="#D3A742" stroke-width="3" stroke-linecap="round"/>
</svg>''';
      case 'fafda':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="33" ry="6" fill="rgba(120,80,20,.12)"/>
<path d="M42 54h56l-6 62c-.4 4-3.8 7-7.8 7H55.8c-4 0-7.4-3-7.8-7l-6-62Z" fill="#FFF4E2"/>
<path d="M42 54h56l-2 14H44l-2-14Z" fill="#E7BF5A"/>
<path d="M49 41c5-8 12-8 16-2l-4 10-12-8ZM66 36c5-8 13-7 16-1l-4 10-12-9ZM82 40c5-6 12-5 14 0l-4 9-10-9Z" fill="#F5D46F"/>
<path d="M54 88h30M52 99h34M55 110h28" stroke="#E8C084" stroke-width="4" stroke-linecap="round"/>
<path d="M59 72h22" stroke="#C58A43" stroke-width="3" stroke-linecap="round"/>
</svg>''';
      case 'facewash':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="27" ry="5.5" fill="rgba(30,110,80,.12)"/>
<rect x="57" y="22" width="26" height="12" rx="4" fill="#5FAE88"/>
<path d="M63 33h14v10c0 3 10 6 12 16l7 41c1 6-3.8 11-9.8 11H57.8c-6 0-10.8-5-9.8-11l7-41c2-10 12-13 12-16V33Z" fill="#CBE8D8"/>
<path d="M51 75c9-3 29-3 38 0l4 26H47l4-26Z" fill="#F4FBF7"/>
<path d="M61 88c2-8 12-11 18-6 5 4 3 12-3 15-7 3-13-2-15-9Z" fill="#5FAE88"/>
<path d="M70 78c-2 8-1 13 3 18" stroke="#DDF3E8" stroke-width="2.2" stroke-linecap="round"/>
<rect x="63" y="50" width="14" height="5" rx="2.5" fill="#A8D5BE"/>
</svg>''';
      case 'icecream-tub':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="32" ry="6" fill="rgba(80,60,140,.12)"/>
<path d="M45 55h50l-6 59c-.4 4-3.8 7-7.8 7H58.8c-4 0-7.4-3-7.8-7l-6-59Z" fill="#C9B6E8"/>
<path d="M42 43c0-4 3-7 7-7h42c4 0 7 3 7 7v17H42V43Z" fill="#F4EFFF"/>
<circle cx="70" cy="42" r="18" fill="#E7D6B8"/>
<path d="M56 40c4-7 12-10 19-7 6 2 9 7 9 12-9 4-21 3-28-5Z" fill="#8B5E2B"/>
<rect x="53" y="75" width="34" height="24" rx="8" fill="#F7F2FF"/>
<path d="M62 87h16" stroke="#8B6BBE" stroke-width="3" stroke-linecap="round"/>
<circle cx="49" cy="36" r="3" fill="#FFF6E6"/>
</svg>''';
      case 'flour':
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="124" rx="34" ry="6" fill="rgba(120,80,20,.12)"/>
<path d="M43 58c0-4 3-7 7-7h40c4 0 7 3 7 7l5 53c.5 4.4-3 8-7.4 8H45.4c-4.4 0-7.9-3.6-7.4-8l5-53Z" fill="#E8D3B4"/>
<path d="M47 51h46l-3 16H50l-3-16Z" fill="#D9BE95"/>
<path d="M52 43c0-6 5-11 11-11h14c6 0 11 5 11 11v8H52v-8Z" fill="#F0E1C9"/>
<ellipse cx="70" cy="92" rx="17" ry="14" fill="#FCF4E5"/>
<path d="M70 104V82M70 88c-5-1-8-4-9-8 5 0 8 2 9 6M70 94c5-1 8-4 9-8-5 0-8 2-9 6" stroke="#C58A43" stroke-width="2.3" stroke-linecap="round"/>
<path d="M58 116c8 2 16 2 24 0" stroke="#D9BE95" stroke-width="3" stroke-linecap="round"/>
</svg>''';
      default:
        return '''
<svg width="140" height="140" viewBox="0 0 140 140" fill="none">
<ellipse cx="70" cy="123" rx="30" ry="6" fill="rgba(20,22,43,.08)"/>
<rect x="40" y="40" width="60" height="70" rx="18" fill="#F1D49A"/>
<circle cx="70" cy="74" r="18" fill="#FFF2D4"/>
</svg>''';
    }
  }
}
