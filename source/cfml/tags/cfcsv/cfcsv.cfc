<cfcomponent output="no" hint="csvToArray function by Ben Nadel: http://www.bennadel.com/index.cfm?event=blog.view&id=2041">
	<!--- --------------------------------------------------------------------------------------- ----
		Blog Entry: UPDATE: Parsing CSV Data Files In ColdFusion With csvToArray()
		Author: Ben Nadel / Kinky Solutions
		Link: http://www.bennadel.com/index.cfm?event=blog.view&id=2041
		Date Posted: Oct 22, 2010 at 5:37 PM
		
		/*
		 * This function was originally called csvToArray.
		 * Since it can now also output as query, I changed the name to parseCSV.
		 * Also added the parameters 'textqualifier', 'returntype', and 'hasColumnNames'.
		 * Paul Klinkenberg, www.lucee.nl, January 30, 2011
		 * Version 1.1, September 22, 2011 : Removed the verbose flag for the regex pattern, so we can use tabs/spaces as delimiters.
		 * Version 1.1.2, September 22, 2011 : Added option to write output to any variable within the pagecontext
		 */
	---- --------------------------------------------------------------------------------------- --->
	<cffunction name="parseCSV" access="public" returntype="any" output="false"
	hint="I take a CSV file or CSV data value and convert it to an array of arrays (edit: or query) based on the given field delimiter. Line delimiter is assumed to be new line / carriage return related.">
		<!--- Define arguments. --->
		<cfargument name="file" type="string" required="false" default="" hint="I am the optional file containing the CSV data." />
		<cfargument name="csv" type="string" required="false" default="" hint="I am the CSV text data (if the file argument was not used)." />
		<cfargument name="delimiter" type="string" required="false" default="," hint="I am the field delimiter (line delimiter is assumed to be new line / carriage return)." />
		<cfargument name="textqualifier" type="string" required="false" default="""" hint="I am the text/string qualifier" />
		<cfargument name="trim" type="boolean" required="false" default="true" hint="I flags whether or not to trim the END of the file for line breaks and carriage returns." />
		<cfargument name="returnType" type="string" hint="array / query" default="query" required="yes" />
		<cfargument name="hasColumnNames" type="boolean" default="true" hint="When using returntype=query, should the first line be used as the column names" />
		<cfargument name="trimlines" type="boolean" required="false" default="false" hint="I flag whether or not to trim the END of every line in the file: removing tabs and spaces" />
		<cfargument name="charset" type="string" required="false" hint="When given, this is the charset to read the file in" />

		<!--- Define the local scope. --->
		<cfset var local = {} />
	 
		<cfset local.returnQuery = false />
		<cfif arguments.returnType neq "array">
			<cfset local.returnQuery = true />
			<cfset arguments.returnType = "query" />
		</cfif>
	
		<!---
			Check to see if we are using a CSV File. If so, then all we
			want to do is move the file data into the CSV variable. That
			way, the rest of the algorithm can be uniform.
		--->
		<cfif len( arguments.file )>
			<!--- Read the file into Data. --->
			<cfif structKeyExists(arguments, "charset") and arguments.charset neq "">
				<cfset arguments.csv = fileRead(arguments.file, arguments.charset) />
			<cfelse>
				<cfset arguments.csv = fileRead( arguments.file ) />
			</cfif>
		</cfif>
	 
		<!---
			ASSERT: At this point, no matter how the data was passed in,
			we now have it in the CSV variable.
		--->

		<!--- Remove trailing spaces and tabs at the end of each line --->
		<cfif arguments.trimlines>
			<cfset arguments.csv = reReplace(
				arguments.csv,
				"[\t ]+([\r\n]|$)",
				"\1",
				"all"
			) />
		</cfif>

		<!---
			Check to see if we need to trim the data. Be default, we are
			going to pull off any new line and carraige returns that are
			at the end of the file (we do NOT want to strip spaces or
			tabs as those are field delimiters).
		--->
		<cfif arguments.trim>
			<!--- Remove trailing line breaks and carriage returns. --->
			<cfset arguments.csv = reReplace(
				arguments.csv,
				"[\r\n]+$",
				"",
				"all"
			) />
		</cfif>
	
		<!--- Make sure the delimiter is just one character. --->
		<cfif (len( arguments.delimiter ) neq 1)>
			<!--- Set the default delimiter value. --->
			<cfset arguments.delimiter = "," />
		</cfif>
		<cfset local.escapedDelimiter = regExSafe(arguments.delimiter) />
		
		<!---  make sure the textqualifier is also just one character --->
		<cfif len(arguments.textqualifier) neq 1>
			<cfset arguments.textqualifier = """" />
		</cfif>
		<cfset local.escapedTextqualifier = regExSafe(arguments.textqualifier) />

		<!---
			Now, let's define the pattern for parsing the CSV data.
		--->
		<cfsavecontent variable="local.regEx"><cfoutput>\G(?:#local.escapedTextqualifier#([^#local.escapedTextqualifier#]*+(?>#local.escapedTextqualifier##local.escapedTextqualifier#[^#local.escapedTextqualifier#]*+)*)#local.escapedTextqualifier#|([^#local.escapedTextqualifier##local.escapedDelimiter#\r\n]*+))(#local.escapedDelimiter#|\r\n?|\n|$)</cfoutput></cfsavecontent>
	 
		<!---
			Create a compiled Java regular expression pattern object
			for the experssion that will be parsing the CSV.
		--->
		<cfset local.pattern = createObject(
			"java",
			"java.util.regex.Pattern"
			).compile(
				javaCast( "string", local.regEx )
			)
		/>
	 
		<!---
			Now, get the pattern matcher for our target text (the CSV
			data). This will allows us to iterate over all the tokens
			in the CSV data for individual evaluation.
		--->
		<cfset local.matcher = local.pattern.matcher(
			javaCast( "string", arguments.csv )
		) />
	 
		<!---
			Create an array to hold the CSV data. We are going to create
			an array of arrays in which each nested array represents a
			row in the CSV data file. We are going to start off the CSV
			data with a single row.
	 
			NOTE: It is impossible to differentiate an empty dataset from
			a dataset that has one empty row. As such, we will always
			have at least one row in our result.
		--->
		<cfif not local.returnQuery>
			<cfset local.csvDataArr = [ [] ] />
		<cfelse>
			<cfset local.csvDataQuery = queryNew("") />
			<cfset local.queryColumnNames = [] />
		</cfif>
		<cfset local.firstRow = true />
		<cfset local.currentRow = 1 />
		<cfset local.currentColNum = 0 />
		
		<!---
			Here's where the magic is taking place; we are going to use
			the Java pattern matcher to iterate over each of the CSV data
			fields using the regular expression we defined above.
	 
			Each match will have at least the field value and possibly an
			optional trailing delimiter.
		--->
		<cfloop condition="local.matcher.find()">
			<cfset local.currentColNum = local.currentColNum + 1 />
			
			<!---
				Next, try to get the qualified field value. If the field
				was not qualified, this value will be null.
			--->
			<cfset local.fieldValue = local.matcher.group(
				javaCast( "int", 1 )
				) />
	 
			<!---
				Check to see if the value exists in the local scope. If
				it doesn't exist, then we want the non-qualified field.
				If it does exist, then we want to replace any escaped,
				embedded quotes.
			--->
			<cfif structKeyExists( local, "fieldValue" )>
	 
				<!---
					The qualified field was found. Replace escpaed
					quotes (two double quotes in a row) with an unescaped
					double quote.
				--->
				<cfset local.fieldValue = replace(
					local.fieldValue,
					"#arguments.textqualifier##arguments.textqualifier#",
					arguments.textqualifier,
					"all"
					) />
	 
			<cfelse>
	 
				<!---
					No qualified field value was found; as such, let's
					use the non-qualified field value.
				--->
				<cfset local.fieldValue = local.matcher.group(
					javaCast( "int", 2 )
					) />
	 
			</cfif>
	 
			<!---
				Now that we have our parsed field value, let's add it to
				the most recently created CSV row collection.
			--->
			<cfif local.returnQuery>
				<cfif local.firstRow>
					<cfif arguments.hasColumnNames>
						<cfif len(trim(local.fieldValue))>
							<cfset arrayAppend(local.queryColumnNames, local.fieldValue) />
						<cfelse>
							<cfset arrayAppend(local.queryColumnNames, "no-column-name") />
						</cfif>
						<cfset local.currentRow = 0 />
					<cfelse>
						<cfset arrayAppend(local.queryColumnNames, "col#local.currentColNum#") />
						<cfif not local.csvDataQuery.recordcount>
							<cfset queryAddRow(local.csvDataQuery) />
						</cfif>
					</cfif>
					<cfset local.tempArray = arguments.hasColumnNames ? [] : [""] />
					<cfset queryAddColumn(local.csvDataQuery, local.queryColumnNames[local.currentColNum], "varchar", local.tempArray ) />
					<cfset local.queryColumnCount = local.currentColNum />
				</cfif>
				<cfif local.currentRow neq 0>
					<!---  in case the amount of columns in a line exceeds the current coumn count, add a column --->
					<cfif local.currentColNum gt local.queryColumnCount>
						<cfset arrayAppend(local.queryColumnNames, "col#local.currentColNum#") />
						<!---  create an aray with empty strings to fill the new query column --->
						<cfset local.tempArray = [] />
						<cfloop from="1" to="#local.csvDataQuery.recordcount#" index="local.i"><cfset local.tempArray[local.i] = "" /></cfloop>
						<cfset queryAddColumn(local.csvDataQuery, local.queryColumnNames[local.currentColNum], "varchar", local.tempArray ) />
						<cfset local.queryColumnCount = local.currentColNum />
					</cfif>
					
					<cfset querySetCell(local.csvDataQuery, local.queryColumnNames[local.currentColNum], local.fieldValue) />
				</cfif>
			<cfelse>
				<cfset arrayAppend(
					local.csvDataArr[ local.currentRow ],
					local.fieldValue
				) />
			</cfif>
	 
			<!---
				Get the delimiter. We know that the delimiter will always
				be matched, but in the case that it matched the end of
				the CSV string, it will not have a length.
			--->
			<cfset local.delimiter = local.matcher.group(
				javaCast( "int", 3 )
				) />
	 
			<!---
				Check to see if we found a delimiter that is not the
				field delimiter (end-of-file delimiter will not have
				a length). If this is the case, then our delimiter is the
				line delimiter. Add a new data array to the CSV
				data collection.
			--->
			<cfif (
				len( local.delimiter ) &&
				(local.delimiter neq arguments.delimiter)
				)>
				<!---  reset/update the counter variables --->
				<cfset local.firstRow = false />
				<cfset local.currentRow = local.currentRow + 1 />
				<cfset local.currentColNum = 0 />
				
				<cfif local.returnQuery>
					<!---  add new query row --->
					<cfset queryAddRow(local.csvDataQuery) />
				<cfelse>
					<!--- Start new row data array. --->
					<cfset arrayAppend(
						local.csvDataArr,
						arrayNew( 1 )
					) />
				</cfif>
	
	 
			<!--- Check to see if there is no delimiter length. --->
			<cfelseif !len( local.delimiter )>
				<!---
					If our delimiter has no length, it means that we
					reached the end of the CSV data. Let's explicitly
					break out of the loop otherwise we'll get an extra
					empty space.
				--->
				<cfbreak />
			</cfif>
		</cfloop>
	 
		<!---
			At this point, our array should contain the parsed contents
			of the CSV value as an array of arrays. Return the array.
		--->
		<cfif local.returnQuery>
			<cfreturn local.csvDataQuery />
		<cfelse>
			<cfreturn local.csvDataArr />
		</cfif>
	</cffunction>
	
	<cffunction name="queryToCSV" access="public" returntype="string" output="false"
	hint="I take a query, and convert it to a CSV string">
		<cfargument name="q" type="query" required="true" />
		<cfargument name="delimiter" type="string" required="false" default="," hint="I am the field delimiter (line delimiter is assumed to be new line / carriage return)." />
		<cfargument name="textqualifier" type="string" required="false" default="""" hint="I am the text/string qualifier" />
		<cfargument name="includeColumnNames" type="boolean" default="true" hint="Create a first line with the column names?" />
		<cfset var local = {} />
		<cfset local.csvData="" />
		<cfset local.columnNames=getQueryColumnList(arguments.q) />
		<cfsavecontent variable="local.csvData"><!---
			---><cfif arguments.includeColumnNames><!--- 
				---><cfset local.delim = "" /><!---
				 ---><cfloop list="#local.columnNames#" index="local.colName"><!--- 
					---><cfoutput>#local.delim##qualifyWhenNeeded(local.colName, arguments.textqualifier, arguments.delimiter)#</cfoutput><!---
					---><cfset local.delim = arguments.delimiter /><!---
				---></cfloop><!--- 
			---></cfif><!--- 
			
			---><cfoutput query="arguments.q">#server.separator.line#<!---
				---><cfset local.delim = "" /><!---
				---><cfloop list="#local.columnNames#" index="local.colName">#local.delim##qualifyWhenNeeded(arguments.q[local.colName][arguments.q.currentrow], arguments.textqualifier, arguments.delimiter)#<!---
					---><cfset local.delim = arguments.delimiter /><!---
				---></cfloop><!---
			---></cfoutput><!---
		---></cfsavecontent>
		
		<cfreturn local.csvData />
	</cffunction>
	
	
	<cffunction name="qualifyWhenNeeded" access="private" returntype="string" output="no">
		<cfargument name="str" type="string" required="yes" />
		<cfargument name="qualifier" type="string" required="no" default="""" />
		<cfargument name="listdelimiter" type="string" required="no" default="," />
		<!--- if we get a timestamp like {ts '2000-01-01 12:34:56'}, change it to a date-time string
		 For Duncan, http://www.lucee.nl/post.cfm/railo-custom-tag-cfcsv#comment-091D7D78-0A5B-4CA7-9BADBCAFDE6E9B2A
		--->
		<cfif find("{ts '", arguments.str) eq 1 and isDate(arguments.str)>
			<cftry>
				<cfset arguments.str = replace(dateformat(arguments.str, "yyyy-mm-dd ") & timeFormat(arguments.str, "HH:mm:ss"), " 00:00:00", "") />
				<cfcatch></cfcatch>
			</cftry>
		<cfelseif find("{d '", arguments.str) eq 1 and isDate(arguments.str)>
			<cftry>
				<cfset arguments.str = dateformat(arguments.str, "yyyy-mm-dd") />
				<cfcatch></cfcatch>
			</cftry>
		</cfif>

		<cfif refind("[\r\n#regExSafe(arguments.listdelimiter)##regExSafe(arguments.qualifier)#]", arguments.str)>
			<cfreturn arguments.qualifier & replace(arguments.str, arguments.qualifier, arguments.qualifier & arguments.qualifier, "all") & arguments.qualifier />
		<cfelse>
			<cfreturn arguments.str />
		</cfif>
	</cffunction>
	
	
	<!--- http://www.lucee.nl/post.cfm/railo-tip-get-a-query-s-columnlist-case-sensitive --->
	<cffunction name="getQueryColumnList" returntype="string" output="no">
		<cfargument name="q" type="query" required="yes" />
		<cfif (structKeyExists(server, "railo") or structKeyExists(server, "lucee"))
				and structKeyExists(arguments.q, "getColumnList")>
			<cfreturn arguments.q.getColumnlist(false) />
		<cfelse>
			<cfreturn arguments.q.columnlist />
		</cfif>
	</cffunction>
	
	<!---  http://www.lucee.nl/post.cfm/regexsafe-function-for-coldfusion --->
	<cffunction name="regExSafe" returntype="string" access="public" output="no">
		<cfargument name="str" type="string" required="yes" />
		<cfparam name="variables.regexSafeTranslations" default="#{}#" />
		<cfif not structKeyExists(variables.regexSafeTranslations, arguments.str)>
			<cfset structInsert(variables.regexSafeTranslations, arguments.str, rereplace(arguments.str, "(?=[\[\]\\^$.|?*+()])", "\", "all"), true) />
		</cfif>
		<cfreturn variables.regexSafeTranslations[arguments.str] />
	</cffunction>

</cfcomponent>