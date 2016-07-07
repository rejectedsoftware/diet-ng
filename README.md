Diet-NG
=======

Diet is a generic compile-time template system based on an XML-like structure. The syntax is heavily influenced by [Jade](http://jade-lang.com) and outputting dynamic HTML is the primary goal. It supports pluggable transformation modules, as well as output modules, so that many other uses are possible.

See the preliminary [Specification][SPEC.md] for a syntax overview.

This repository contians the designated successor implementation of the [`vibe.templ.diet` module](https://vibed.org/api/vibe.templ.diet/) of [vibe.d](https://vibed.org/). It's currently still in development and shouldn't be used for production yet.

[![Build Status](https://travis-ci.org/rejectedsoftware/diet-ng.svg?branch=master)](https://travis-ci.org/rejectedsoftware/diet-ng)


Example
-------

	doctype html
	- auto title = "Hello, <World>";
	html
		head
			title #{title} - example page
		body
			h1= title

			h2 Index
			ol.pageindex
				- foreach (i; 0 .. 3)
					li: a(href="##{i}") Point #{i}

			- foreach (i; 0 .. 3)
				h2(id=i) Point #{i}
				p.
					These are the #[i contents] of point #{i}. Multiple
					lines of text are contained in this paragraph.

Generated HTML output:

	<!DOCTYPE html>
	<html>
		<head>
			<title>Hello, &lt;World&gt; - example page</title>
		</head>
		<body>
			<h1>Hello, &lt;World&gt;</h1>
			<h2>Index</h2>
			<ol class="pageindex">
				<li><a href="#0">Point 0</a></li>
				<li><a href="#1">Point 1</a></li>
				<li><a href="#2">Point 2</a></li>
			</ol>
			<h2 id="0">Point 0</h2>
			<p>These are the <i>contents</i> of point 0. Multiple
			lines of text are contained in this paragraph.</p>
			<h2 id="1">Point 1</h2>
			<p>These are the <i>contents</i> of point 1. Multiple
			lines of text are contained in this paragraph.</p>
			<h2 id="2">Point 2</h2>
			<p>These are the <i>contents</i> of point 2. Multiple
			lines of text are contained in this paragraph.</p>
		</body>
	</html>
