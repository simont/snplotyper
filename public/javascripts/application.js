// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


// Allows hide/show of div tags on page

function show_sections(section_id,no_text_change_flag) {

	element_id = 'sec-' + section_id
	new Effect[Element.visible(element_id) ? 
	'BlindUp' : 'BlindDown'](element_id, {duration: 0.25});


	if (Element.visible(element_id)) {
		document.getElementById('sec-text-'+ section_id).innerHTML="+";
	}
	else {
		document.getElementById('sec-text-'+ section_id).innerHTML="-";
	}

}