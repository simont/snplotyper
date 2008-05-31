/* snplotyper.js

Functions related to the Snplotyper SNP tool

Simon Twigger, (c) 2007*/


function show_sections2(section_id) {

	element_id = 'sec-' + section_id
	new Effect[Element.visible(element_id) ? 
	'BlindUp' : 'BlindDown'](element_id, {duration: 0.25});


	if (Element.visible(element_id)) {
		if (document.getElementById('sec-text-'+ section_id).innerHTML == "[hide]") {
			document.getElementById('sec-text-'+ section_id).innerHTML="[show]";
		}
		else {
			document.getElementById('sec-text-'+ section_id).innerHTML="[show]";
		}
	}
	else {
		if (document.getElementById('sec-text-'+ section_id).innerHTML == "[show]") {
			document.getElementById('sec-text-'+ section_id).innerHTML="[hide]";
		}
		else {
			document.getElementById('sec-text-'+ section_id).innerHTML="[hide]";
		}
	}
}

// Used on analysis/_edit_analysis_form page to turn on and off radio buttons 

function activate_strain_options(strain_id) {
	
	if (document.getElementById('strain[' + strain_id + ']').checked) {
		document.getElementById(strain_id + '_group_1').disabled = false
		document.getElementById(strain_id + '_group_2').disabled = false
		document.getElementById('output[primary_strain]_' + strain_id).disabled = false
	}
	else {
		document.getElementById(strain_id + '_group_1').disabled = true
		document.getElementById(strain_id + '_group_2').disabled = true
		document.getElementById('output[primary_strain]_' + strain_id).disabled = true
	}
}

function include_all_strains_starting_with(section_letter) {

	var class_name = 'strain_checkbox_'+section_letter;
	// Get all the checkbox elements for strains starting with this letter
	var strain_checkbox_elements = getElementsByClassName(class_name);
	
	// Get the main checkbox status that toggles all the strains that start with this letter
	var letter_checkbox = document.getElementById('strain_letter_'+section_letter);

	for(str = 0; str < strain_checkbox_elements.length; str++) {
		if(letter_checkbox.checked == true) {
			strain_checkbox_elements[str].checked = true;
		}
		else {
			strain_checkbox_elements[str].checked = false;
		}
			// 	
			var str_id = /strain\[(\d+)\]/i.exec(strain_checkbox_elements[str].id);
			alert("found" + str_id[1] + "Size: " + strain_checkbox_elements.length)
			activate_strain_options('18');
	}
}

function getElementsByClassName(strClass, strTag, objContElm) {
	strTag = strTag || "*";
	objContElm = objContElm || document;
	var objColl = objContElm.getElementsByTagName(strTag);
	if (!objColl.length &&  strTag == "*" &&  objContElm.all) objColl = objContElm.all;
	var arr = new Array();
	var delim = strClass.indexOf('|') != -1  ? '|' : ' ';
	var arrClass = strClass.split(delim);
	for (var i = 0, j = objColl.length; i < j; i++) {
		var arrObjClass = objColl[i].className.split(' ');
		if (delim == ' ' && arrClass.length > arrObjClass.length) continue;
		var c = 0;
		comparisonLoop:
		for (var k = 0, l = arrObjClass.length; k < l; k++) {
			for (var m = 0, n = arrClass.length; m < n; m++) {
				if (arrClass[m] == arrObjClass[k]) c++;
				if (( delim == '|' && c == 1) || (delim == ' ' && c == arrClass.length)) {
					arr.push(objColl[i]);
					break comparisonLoop;
				}
			}
		}
	}
	return arr;
}

