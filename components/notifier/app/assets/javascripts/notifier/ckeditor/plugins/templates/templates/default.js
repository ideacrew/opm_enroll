/**
 * @license Copyright (c) 2003-2017, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or http://ckeditor.com/license
 */

// Register a templates definition set named "default".
CKEDITOR.addTemplates( 'default', {
	// The name of sub folder which hold the shortcut preview images of the
	// templates.
	imagesPath: CKEDITOR.getUrl( CKEDITOR.plugins.getPath( 'templates' ) + 'templates/images/' ),

	// The templates definitions.
	templates: [ {
		title: 'Employer Template',
		image: 'template1.gif',
		description: 'Standard template for the notices received by Employers.',
		html: "<p>&nbsp;</p>" +
"<p>Email notification sent to: #{employer_profile.email}</p>" +
"<p>#{employer_profile.notice_date}</p>" +
"<p><strong>SUBJECT: &lt;Change subject&gt;</strong></p>" +
"<p>Dear #{employer_profile.employer_name}:</p>" +
"<p>&lt;Paste Your Notice Body Here&gt;</p>" +
"<h3>For Questions or Assistance:</h3>"+
"<p>Please contact your broker for further assistance. You can also contact the #{site_short_name} with any questions:</p>" +
"<ul>" +
	"<li>By calling #{Settings.contact_center.phone_number}</li>" +
	"<li>TTY: #{Settings.contact_center.tty}</li>" +
	"<li>Online at: <a href='#{Settings.site.home_url}'>#{Settings.site.website_name}</a></li>" +
"</ul>" +
"<p>You can also find more information on our website at <a href='http://​#{Settings.site.website_name}'>#{Settings.site.website_name}</a></p>" +
"<p>[[ if employer_profile.broker_present? ]]</p>" +
"<table border='0'cellpadding='0' cellspacing='0' style='height:auto; width:auto'>" +
	"<tbody>" +
		"<tr>" +
			"<td><strong>Broker: &nbsp;&nbsp;</strong></td>" +
			"<td>#{employer_profile.broker.primary_fullname}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employer_profile.broker.organization}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employer_profile.broker.phone}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employer_profile.broker.email}</td>" +
		"</tr>" +
	"</tbody>" +
"</table>" +
"<p>[[ else ]]</p>" +
"<p>If you do not currently have a broker, you can reach out to one of our many trained experts by clicking on the &ldquo;Find a Broker&rdquo; link in your employer account or calling #{Settings.contact_center.phone_number}<br />" +
"[[ end ]]</p>" +
"<p>___________________________________________________________________________________________________________________________________________________</p>" +
"<p><small>This notice is being provided in accordance with &lt;Insert Legal Compliance Code&gt;.</small></p>"
	},
	{
		title: 'Employee Template',
		image: 'template1.gif',
		description: 'Standard template for the notices received by Employees.',
		html: "<p>&nbsp;</p>" +
"<p>Email notification sent to: #{employee_profile.email}</p>" +
"<p>​#{employee_profile.notice_date}</p>" +
"<p><strong>SUBJECT: &lt;Change subject&gt;</strong></p>" +
"<p>Dear ​#{employee_profile.first_name} ​#{employee_profile.last_name}:</p>" +
"<p>&lt;Paste Your Notice Body Here&gt;</p>" +
"<h3>For Questions or Assistance:</h3>"+
"<p>[[ if employee_profile.broker_present? ]]</p>" +
"<p>Contact your employer or your broker for further assistance.</p>" +
"<p>[[ else ]]</p>" +
"<p>Contact your employer for further assistance.<br />" +
"[[ end ]]</p>" +
"<p>You can also contact the #{site_short_name} with any questions:</p>" +
"<ul>" +
	"<li>By calling #{Settings.contact_center.phone_number}</li>" +
	"<li>TTY: #{Settings.contact_center.tty}</li>" +
	"<li>Online at: <a href='#{Settings.site.home_url}'>#{Settings.site.website_name}</a></li>" +
"</ul>" +
"<p>You can also find more information on our website at <a href='http://​#{Settings.site.website_name}'>#{Settings.site.website_name}</a></p>" +
"[[ if employee_profile.broker_present? ]]" +
"<table border='0'cellpadding='0' cellspacing='0' style='height:auto; width:auto'>" +
	"<tbody>" +
		"<tr>" +
			"<td><strong>Broker: &nbsp;&nbsp;</strong></td>" +
			"<td>#{employee_profile.broker.primary_fullname}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employee_profile.broker.organization}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employee_profile.broker.phone}</td>" +
		"</tr>" +
		"<tr>" +
			"<td>&nbsp;</td>" +
			"<td>#{employee_profile.broker.email}</td>" +
		"</tr>" +
	"</tbody>" +
"</table>" +
"[[ end ]]" +
"<p>___________________________________________________________________________________________________________________________________________________</p>" +
"<p><small>This notice is being provided in accordance with &lt;Insert Legal Compliance Code&gt;.</small></p>"
	},
	{
		title: 'Broker Template',
		image: 'template1.gif',
		description: 'Standard template for the notices received by Brokers.',
		html: "<p>&nbsp;</p>" +
"<p>Email notification sent to: #{broker_profile.email}</p>" +
"<p>#{broker_profile.notice_date}</p>" +
"<p><strong>SUBJECT: &lt;Change subject&gt;</strong></p>" +
"<p>Dear #{broker_profile.first_name} #{broker_profile.last_name}:</p>" +
"<p>&lt;Paste Your Notice Body Here&gt;</p>" +
"<h3>For Questions or Assistance:</h3>"+
"<p>Please contact #{site_short_name} with any questions:</p>" +
"<ul>" +
	"<li>By calling #{Settings.contact_center.phone_number}.</li>  " +
	"<li>TTY: #{Settings.contact_center.tty}</li>" +
	"<li>Online at: <a href='#{Settings.site.home_url}'>#{Settings.site.website_name}</a></li>" +
"</ul>" +
"<p>You can also find more information on our website at <a href='http://​#{Settings.site.website_name}'>#{Settings.site.website_name}</a></p>"
	},
  {
		title: 'Broker Agency Template',
		image: 'template1.gif',
		description: 'Standard template for the notices received by Broker Agencies.',
		html: "<p>&nbsp;</p>" +
"<p>#{broker_agency_profile.notice_date}</p>" +
"<p><strong>SUBJECT: &lt;Change subject&gt;</strong></p>" +
"<p>Dear #{broker_agency_profile.broker_agency_name}:</p>" +
"<p>&lt;Paste Your Notice Body Here&gt;</p>" +
"<h3>For Questions or Assistance:</h3>"+
"<p>Please contact #{site_short_name} with any questions:</p>" +
"<ul>" +
	"<li>By calling #{Settings.contact_center.phone_number}.</li>  " +
	"<li>TTY: #{Settings.contact_center.tty}</li>" +
	"<li>Online at: <a href='#{Settings.site.home_url}'>#{Settings.site.website_name}</a></li>" +
"</ul>" +
"<p>You can also find more information on our website at <a href='http://​#{Settings.site.website_name}'>#{Settings.site.website_name}</a></p>"
	},
	{
		title: 'General Agency Template',
		image: 'template1.gif',
		description: 'Standard template for the notices received by General Agencies.',
		html: "<p>&nbsp;</p>" +
"<p>Email notification sent to: #{general_agency.email}</p>" +
"<p>#{general_agency.notice_date}</p>" +
"<p><strong>SUBJECT: &lt;Change subject&gt;</strong></p>" +
"<p>Dear #{general_agency.legal_name}:</p>" +
"<p>&lt;Paste Your Notice Body Here&gt;</p>" +
"<h3>For Questions or Assistance:</h3>"+
"<p>Please contact #{site_short_name} with any questions:</p>" +
"<ul>" +
	"<li>By calling #{Settings.contact_center.phone_number}</li>" +
	"<li>TTY: #{Settings.contact_center.tty}</li>" +
	"<li>Online at: <a href='#{Settings.site.home_url}'>#{Settings.site.website_name}</a></li>" +
"</ul>" +
"<p>You can also find more information on our website at <a href='http://​#{Settings.site.website_name}'>#{Settings.site.website_name}</a></p>"
	}
	]
} );
