// 公式交给 MathJax 3 排版：\( … \) 行内，\[ … \] 独立成行。
window.MathJax = { tex: { inlineMath: [["\\(", "\\)"]], displayMath: [["\\[", "\\]"]] } };
(function () {
  var s = document.createElement("script");
  s.src = "https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-chtml.js";
  s.async = true;
  document.head.appendChild(s);
})();
