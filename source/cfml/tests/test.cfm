<cfset x = new cfcsv.cfcsv() />

<cfdirectory action="list" directory="#expandpath('/WEB-INF/lucee/logs')#" name="q" />
<cfdump var="#q#"/>
<table border="1" cellpadding="3" cellspacing="0">
	<thead>
		<tr>
			<th colspan="3">&nbsp;</th>
			<th colspan="2">QUERY</th>
			<th colspan="2">ARRAY</th>
		</tr>
		<tr>
			<th>name</th>
			<th>file size</th>
			<th>csv rows</th>
			<th>parse time</th>
			<th>time per row</th>
			<th>parse time</th>
			<th>time per row</th>
		</tr>
	</thead>
	<cfoutput query="q">
		<tr>
			<td>#q.name#</td>
			<td>#ceiling(q.size/1024)# KB</td>
			<cfset i = gettickcount() />
			<cfset thequery = x.parseCSV(file='#q.directory##server.separator.file##q.name#') />
			<cfset time = gettickcount() - i />
			<td>#thequery.recordcount#</td>
			<td>#time# ms. (<a href="?dump=#q.name#&amp;returntype=query">dump</a>)</td>
			<td><cfif thequery.recordcount>#time / thequery.recordcount# ms.<cfelse>-</cfif></td>

			<cfset i = gettickcount() />
			<cfset thearray = x.parseCSV(file='#q.directory##server.separator.file##q.name#', returntype="array") />
			<cfset time = gettickcount() - i />
			<td>#time# ms. (<a href="?dump=#q.name#&amp;returntype=array">dump</a>)</td>
			<td><cfif arrayLen(thearray)>#time / arrayLen(thearray)# ms.<cfelse>-</cfif></td>
		</tr>
	</cfoutput>
</table>
<cfif structKeyExists(url, "dump")>
	<cfset filepath = '#q.directory##server.separator.file##url.dump#' />
	<h1><cfoutput>x.parseCSV(file="#filepath#", returntype="#url.returntype#")</cfoutput></h1>
	<cfdump var="#x.parseCSV(file=filepath, returntype=url.returntype)#" />
</cfif>