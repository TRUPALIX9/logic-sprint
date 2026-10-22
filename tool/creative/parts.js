// Fills each .brand with the logo and wordmark, and wraps each <div class="phone"><img></div> in a device frame with status bar,
// Dynamic Island and side buttons. The status bar covers the screenshot's own
// empty status-bar strip, so the top of the screen reads like a real iPhone.
const icons = `
  <svg viewBox="0 0 34 22"><g fill="#fff">
    <rect x="0" y="15" width="6" height="7" rx="1.5"/><rect x="9" y="10" width="6" height="12" rx="1.5"/>
    <rect x="18" y="5" width="6" height="17" rx="1.5"/><rect x="27" y="0" width="6" height="22" rx="1.5"/></g></svg>
  <svg viewBox="0 0 30 22"><g fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round">
    <path d="M2.5 8.2a18 18 0 0 1 25 0"/><path d="M7.5 13a11 11 0 0 1 15 0"/></g>
    <circle cx="15" cy="18.6" r="2.6" fill="#fff"/></svg>
  <svg viewBox="0 0 50 22"><rect x="1" y="1" width="42" height="20" rx="6" fill="none" stroke="#fff" stroke-opacity=".45" stroke-width="2"/>
    <rect x="4" y="4" width="36" height="14" rx="3.5" fill="#fff"/><rect x="45.5" y="7.5" width="3" height="7" rx="1.5" fill="#fff" fill-opacity=".45"/></svg>`;

for (const phone of document.querySelectorAll('.phone')) {
  const img = phone.querySelector('img');
  phone.innerHTML = `
    <div class="btn" style="left:-.7cqw;top:24cqw;height:8cqw"></div>
    <div class="btn" style="left:-.7cqw;top:38cqw;height:14cqw"></div>
    <div class="btn" style="left:-.7cqw;top:56cqw;height:14cqw"></div>
    <div class="btn" style="right:-.7cqw;top:44cqw;height:22cqw"></div>
    <div class="btn" style="right:-.7cqw;top:132cqw;height:16cqw"></div>
    <div class="frame"><div class="bezel"><div class="screen">
      ${img.outerHTML}
      <div class="status"><span>9:41</span><span class="icons">${icons}</span></div>
      <div class="island"></div>
    </div></div></div>`;
}

const LOGO = `<svg viewBox="0 0 125 100"><g stroke-linecap="round" fill="none">
  <path d="M8 32 H33 M3 50 H28 M8 68 H33" stroke="#677A8C" stroke-width="9"/>
  <path d="M48 12 L86 50 L48 88" stroke="#3B7BF0" stroke-width="18" stroke-linejoin="round"/>
  <path d="M80 12 L118 50 L80 88" stroke="#34C29A" stroke-width="18" stroke-linejoin="round"/></g></svg>`;
for (const el of document.querySelectorAll('.brand'))
  el.innerHTML = `${LOGO}<div class="word">LOGIC<b>SPRINT</b></div>`;
