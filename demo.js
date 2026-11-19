// Text-size demo: the settings rows follow iOS body sizes from xSmall to AX5.
(function () {
  var sizes = [
    ["Extra small", 14], ["Small", 15], ["Medium", 16], ["Large (default)", 17],
    ["Extra large", 19], ["Extra extra large", 21], ["Extra extra extra large", 23],
    ["AX1", 28], ["AX2", 33], ["AX3", 40], ["AX4", 47], ["AX5 (largest)", 53]
  ];
  var range = document.getElementById("size");
  var adaptive = document.getElementById("adaptive");
  var phone = document.getElementById("phone");
  var readout = document.getElementById("size-readout");
  var caption = document.getElementById("phone-desc");
  if (!range || !phone) return;

  function update() {
    var s = sizes[Number(range.value)];
    var isAX = Number(range.value) >= 7;
    var pct = Math.round((s[1] / 17) * 100);
    var text = s[0] + ", " + s[1] + " pt (" + pct + "%)";
    readout.textContent = text;
    range.setAttribute("aria-valuetext", text);
    // Scale relative to the page's own text size, so the demo also follows the reader's browser setting.
    phone.style.fontSize = (s[1] * 0.7 / 16) + "rem"; // the mock phone is drawn at 70% of a real iPhone
    phone.classList.toggle("ax", isAX);
    phone.classList.toggle("adaptive", adaptive.checked);

    var msg;
    if (!isAX) {
      msg = s[1] <= 17
        ? "At this size every row fits on one line."
        : "Text is bigger and the rows still fit, just.";
    } else if (adaptive.checked) {
      msg = "At " + s[0] + " each value moves under its name, so nothing is cut off.";
    } else {
      msg = "At " + s[0] + " the names and values are cut off with “…”. Turn on stacking to fix it.";
    }
    caption.textContent = msg;
  }
  range.addEventListener("input", update);
  adaptive.addEventListener("change", update);
  update();
})();
