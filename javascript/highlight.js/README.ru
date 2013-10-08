<!DOCTYPE html><html><head><title>Starphleet Documentation</title><link rel="stylesheet" href="main.css"><link rel="stylesheet" href="javascript/highlight.js/styles/monokai.css"><script src="javascript/jquery.min.js"></script><script src="javascript/bootstrap.min.js"></script><script src="javascript/toc.min.js"></script><script src="javascript/highlight.js/highlight.pack.js"></script><script src="javascript/main.js"></script><meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no"></head><body><div class="navbar navbar-fixed-top"><div><a href="index.html" class="navbar-brand">Starphleet</a></div></div><div id="leftnav" class="leftnav"><div class="sidebar-nav sidebar-nav-fixed"><div id="toc"></div></div></div><div id="main" class="main"><div id="content" class="content"><h1>Highlight.js</h1>
<p>Highlight.js нужен для подсветки синтаксиса в примерах кода в блогах,
форумах и вообще на любых веб-страницах. Пользоваться им очень просто,
потому что работает он автоматически: сам находит блоки кода, сам
определяет язык, сам подсвечивает.</p>
<p>Автоопределением языка можно управлять, когда оно не справляется само (см.
дальше &quot;Эвристика&quot;).</p>
<h2>Простое использование</h2>
<p>Подключите библиотеку и стиль на страницу и повесть вызов подсветки на
загрузку страницы:</p>
<pre><code class="language-html">&lt;link rel=&quot;stylesheet&quot; href=&quot;styles/default.css&quot;&gt;
&lt;script src=&quot;highlight.pack.js&quot;&gt;&lt;/script&gt;
&lt;script&gt;hljs.initHighlightingOnLoad();&lt;/script&gt;</code></pre>
<p>Весь код на странице, обрамлённый в теги <code>&lt;pre&gt;&lt;code&gt; .. &lt;/code&gt;&lt;/pre&gt;</code>
будет автоматически подсвечен. Если вы используете другие теги или хотите
подсвечивать блоки кода динамически, читайте &quot;Инициализацию вручную&quot; ниже.</p>
<ul>
<li><p>Вы можете скачать собственную версию &quot;highlight.pack.js&quot; или сослаться
на захостенный файл, как описано на странице загрузки:
<a href="http://softwaremaniacs.org/soft/highlight/download/">http://softwaremaniacs.org/soft/highlight/download/</a></p>
</li>
<li><p>Стилевые темы можно найти в загруженном архиве или также использовать
захостенные. Чтобы сделать собственный стиль для своего сайта, вам
будет полезен справочник классов в файле <a href="http://github.com/isagalaev/highlight.js/blob/master/classref.txt">classref.txt</a>, который тоже
есть в архиве.</p>
</li>
</ul>
<h2>node.js</h2>
<p>Highlight.js можно использовать в node.js. Библиотеку со всеми возможными языками можно
установить с NPM:</p>
<pre><code>npm install highlight.js</code></pre>
<p>Также её можно собрать из исходников с только теми языками, которые нужны:</p>
<pre><code>python tools/build.py -tnode lang1 lang2 ..</code></pre>
<p>Использование библиотеки:</p>
<pre><code class="language-javascript">var hljs = require(&#39;highlight.js&#39;);

// Если вы знаете язык
hljs.highlight(lang, code).value;

// Автоопределение языка
hljs.highlightAuto(code).value;</code></pre>
<h2>Замена TABов</h2>
<p>Также вы можете заменить символы TAB (&#39;\x09&#39;), используемые для отступов, на
фиксированное количество пробелов или на отдельный <code>&lt;span&gt;</code>, чтобы задать ему
какой-нибудь специальный стиль:</p>
<pre><code class="language-html">&lt;script type=&quot;text/javascript&quot;&gt;
  hljs.tabReplace = &#39;    &#39;; // 4 spaces
  // ... or
  hljs.tabReplace = &#39;&lt;span class=&quot;indent&quot;&gt;\t&lt;/span&gt;&#39;;

  hljs.initHighlightingOnLoad();
&lt;/script&gt;</code></pre>
<h2>Инициализация вручную</h2>
<p>Если вы используете другие теги для блоков кода, вы можете инициализировать их
явно с помощью функции <code>highlightBlock(code, tabReplace, useBR)</code>. Она принимает
DOM-элемент с текстом расцвечиваемого кода и опционально - строчку для замены
символов TAB.</p>
<p>Например с использованием jQuery код инициализации может выглядеть так:</p>
<pre><code class="language-javascript">$(document).ready(function() {
  $(&#39;pre code&#39;).each(function(i, e) {hljs.highlightBlock(e)});
});</code></pre>
<p><code>highlightBlock</code> можно также использовать, чтобы подсветить блоки кода,
добавленные на страницу динамически. Только убедитесь, что вы не делаете этого
повторно для уже раскрашенных блоков.</p>
<p>Если ваш блок кода использует <code>&lt;br&gt;</code> вместо переводов строки (т.е. если это не
<code>&lt;pre&gt;</code>), передайте <code>true</code> третьим параметром в <code>highlightBlock</code>:</p>
<pre><code class="language-javascript">$(&#39;div.code&#39;).each(function(i, e) {hljs.highlightBlock(e, null, true)});</code></pre>
<h2>Эвристика</h2>
<p>Определение языка, на котором написан фрагмент, делается с помощью
довольно простой эвристики: программа пытается расцветить фрагмент всеми
языками подряд, и для каждого языка считает количество подошедших
синтаксически конструкций и ключевых слов. Для какого языка нашлось больше,
тот и выбирается.</p>
<p>Это означает, что в коротких фрагментах высока вероятность ошибки, что
периодически и случается. Чтобы указать язык фрагмента явно, надо написать
его название в виде класса к элементу <code>&lt;code&gt;</code>:</p>
<pre><code class="language-html">&lt;pre&gt;&lt;code class=&quot;html&quot;&gt;...&lt;/code&gt;&lt;/pre&gt;</code></pre>
<p>Можно использовать рекомендованные в HTML5 названия классов:
&quot;language-html&quot;, &quot;language-php&quot;. Также можно назначать классы на элемент
<code>&lt;pre&gt;</code>.</p>
<p>Чтобы запретить расцветку фрагмента вообще, используется класс &quot;no-highlight&quot;:</p>
<pre><code class="language-html">&lt;pre&gt;&lt;code class=&quot;no-highlight&quot;&gt;...&lt;/code&gt;&lt;/pre&gt;</code></pre>
<h2>Экспорт</h2>
<p>В файле export.html находится небольшая программка, которая показывает и дает
скопировать непосредственно HTML-код подсветки для любого заданного фрагмента кода.
Это может понадобится например на сайте, на котором нельзя подключить сам скрипт
highlight.js.</p>
<h2>Координаты</h2>
<ul>
<li>Версия: 7.3</li>
<li>URL:    <a href="http://softwaremaniacs.org/soft/highlight/">http://softwaremaniacs.org/soft/highlight/</a></li>
<li>Автор:  Иван Сагалаев (<a href="&#109;&#x61;&#x69;&#108;&#116;&#111;&#x3a;&#109;&#x61;&#110;&#105;&#x61;&#99;&#x40;&#x73;&#111;&#x66;&#116;&#119;&#x61;&#114;&#x65;&#x6d;&#x61;&#110;&#x69;&#97;&#99;&#x73;&#46;&#x6f;&#114;&#x67;">&#109;&#x61;&#110;&#105;&#x61;&#99;&#x40;&#x73;&#111;&#x66;&#116;&#119;&#x61;&#114;&#x65;&#x6d;&#x61;&#110;&#x69;&#97;&#99;&#x73;&#46;&#x6f;&#114;&#x67;</a>)</li>
</ul>
<p>Лицензионное соглашение читайте в файле LICENSE.
Список соавторов читайте в файле AUTHORS.ru.txt</p>
</div><footer><p>Copyright &copy 2013</p></footer></div></body></html>