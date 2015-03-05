<cfcomponent name="cfcsv" output="no">
<!---
	>> ALSO SEE THE COPYRIGHT LICENSE AT ./cfcsv/cfcsv.cfc
	
	This software is licensed under the BSD license. See http://www.opensource.org/licenses/bsd-license.php
	Project page: http://www.lucee.nl/post.cfm/railo-custom-tag-cfcsv
	Version: 1.0, 3 february 2011
	Version 1.1.2, September 22, 2011 : Added option to write output to any variable within the pagecontext
	
	Copyright (c) 2011-2015, Paul Klinkenberg (paul@ongevraagdadvies.nl)
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification,
	are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list
	  of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this
	  list of conditions and the following disclaimer in the documentation and/or
	  other materials provided with the distribution.
    * Neither the name of the <ORGANIZATION> nor the names of its contributors may be
	  used to endorse or promote products derived from this software without specific
	  prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
	SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
	BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
	WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--->

	<!--- Meta data --->
	<cfset this.metadata.attributetype="fixed" />
	<cfset this.metadata.attributes={
		action:					{required:true, type:"string"}
		
		, variable:				{required:false, type:"string", default: "cfcsv"}
		, output:				{required:false, type:"string", default:"query"}
		, file:					{required:false, type:"string"}
		, data:					{required:false, type:"string"}
		, textqualifier:		{required:false, type:"string", default:""""}
		, delimiter:			{required:false, type:"string", default:","}
		, trimendoffile:		{required:false, type:"boolean", default:true}
		, hascolumnnames:		{required:false, type:"boolean", default:true}
		, query:				{required:false, type:"query"}
		, includeColumnNames:	{required:false, type:"boolean", default:true}
		, trimlines:			{required:false, type:"boolean", default:false}
		, charset:				{required:false, type:"string"}
	}>
	<cfset this.metadata.requiredAttributesPerAction = {
		parse: []
		, create: ['query']
	} />


	<cffunction name="init" output="no" returntype="void"
		hint="invoked after tag is constructed">
		<cfargument name="hasEndTag" type="boolean" required="yes" />
		<cfargument name="parent" type="component" required="no" hint="the parent cfc custom tag, if there is one" />
		<cfset variables.hasEndTag = arguments.hasEndTag />
		<cfset variables.parent = arguments.parent />
	</cffunction> 
	
	<cffunction name="onStartTag" output="no" returntype="boolean">
		<cfargument name="attributes" type="struct" />
		<cfargument name="caller" type="struct" />
 		<cfset variables.attributes = arguments.attributes />
		<cfset var action = getAttribute('action') />
		<cfset var outputFormat = getAttribute('output') />
		<cfset var CSVObj = _getCSVObject(arguments.attributes) />
		
		
		<!--- check type --->
		<cfif structKeyExists(this.metadata.requiredAttributesPerAction, action)>
			<cfset var attrName = "" />
			<cfloop array="#this.metadata.requiredAttributesPerAction[action]#" index="attrName">
				<cfif not attributeExists(attrName)>
					<cfthrow message="cfcsv: when action is '#action#', the atribute [#attrName#] is required!" />
				</cfif>
			</cfloop>
		<cfelse>
			<cfthrow message="cfcsv does not have an action '#htmleditformat(action)#'!" detail="Only actions '#structKeyList(this.metadata.requiredAttributesPerAction)#' are available." />
		</cfif>
		<cfif len(getAttribute("delimiter")) neq 1>
			<cfthrow message="cfcsv: attribute [delimiter] can only be 1 character long" />
		</cfif>
		<cfif len(getAttribute("textqualifier")) neq 1>
			<cfthrow message="cfcsv: attribute [textqualifier] can only be 1 character long" />
		</cfif>
		<cfif action eq "parse">
			<!---  output format correct? --->
			<cfif not listfindNoCase("query,array", outputFormat)>
				<cfthrow message="cfcsv: atribute [output] can only be one of the values [query,array]" />
			</cfif>
			<cfif not attributeExists("file") and not attributeExists("data")>
				<cfthrow message="cfcsv: either attribute [file] or attribute [data] must be given!" />
			</cfif>
			<cfif attributeExists("file") and attributeExists("data")>
				<cfthrow message="cfcsv: both attributes [file] and [data] are given! You must only supply one of them!" />
			</cfif>
			<cfif attributeExists("file")>
				<cfif not fileExists(getAttribute("file"))>
					<cfset var pathFromCaller = getDirectoryFromPath(getParentTemplatePath()) & getAttribute("file") />
					<cfif fileExists(pathFromCaller)>
						<cfset setAttribute("file", pathFromCaller) />
					<cfelse>
						<cfthrow message="CSV file path [#getAttribute('file')#] or [#pathFromCaller#] does not exist!" />
					</cfif>
				</cfif>
			</cfif>
		</cfif>
		
		<!--- do action --->
		<cfset var returnedData = "" />
		<cfif action eq "parse">
			<cfset var i = "" />
			<cfinvoke component="#CSVObj#" method="parseCSV" returnvariable="returnedData">
				<cfloop list="file,textqualifier,delimiter,hascolumnnames,charset,trimlines" index="i">
					<cfif attributeExists(i)>
						<cfinvokeargument name="#i#" value="#getAttribute(i)#" />
					</cfif>
				</cfloop>
				<cfif attributeExists("data")>
					<cfinvokeargument name="csv" value="#getAttribute('data')#" />
				</cfif>
				<cfif attributeExists("trimendoffile")>
					<cfinvokeargument name="trim" value="#getAttribute('trimendoffile')#" />
				</cfif>
				<cfinvokeargument name="returnType" value="#outputFormat#" />
			</cfinvoke>
		<cfelseif action eq "create">
			<cfset returnedData = CSVObj.queryToCSV(
				q=getAttribute('query')
				, delimiter=getAttribute('delimiter')
				, textqualifier=getAttribute('textqualifier')
				, includeColumnNames=getAttribute('includeColumnNames')
			) />
		</cfif>
		<cfset _insertValueIntoCaller(arguments.caller, returnedData, false) />
		
		<cfreturn true />
	</cffunction>


	<cffunction name="onEndTag" output="no" returntype="boolean">
		<cfargument name="attributes" type="struct">
		<cfargument name="caller" type="struct">				
  		<cfargument name="generatedContent" type="string">
		<cfreturn false/>	
	</cffunction>


	<cffunction name="_getCSVObject" access="private" returntype="any" output="no">
		<cfreturn createObject("component", "cfcsv.cfcsv") />
	</cffunction>
	


<cffunction name="_insertValueIntoCaller" access="private" returntype="void" output="no">
	<cfargument name="caller" type="struct" required="yes" />
	<cfargument name="value" type="any" required="yes" hint="The value to insert into the caller page" />
	<cfargument name="optionalToSTDOUT" type="boolean" required="no" default="false" hint="If no 'variable' attr. is given, should we output the value to STDOUT or to a variable with the name of this tag" />
	<cfif attributeExists('variable')>
		<cfset var varname = getAttribute('variable') />
		<cfset var scopeName = listFirst(varName, '.') />
		<cfif listLen(varname, '.') eq 1
		or scopeName eq "local"
		or scopeName eq "variables"
		or not listFindNoCase("server,cookie,request,form,url,application,client,session,cfthread", scopeName)>
			<cfset setVariable("arguments.caller.#varname#", arguments.value) />
		<cfelse>
			<cfset setVariable(varName, arguments.value) />
		</cfif>
	<cfelseif arguments.optionalToSTDOUT>
		<cfoutput>#arguments.value#</cfoutput>
	<cfelse>
		<cfset arguments.caller["cfcsv"] = arguments.value />
	</cfif>
</cffunction>


	<!---   attributes   --->
	<cffunction name="getAttribute" output="false" access="private" returntype="any">
		<cfargument name="key" required="true" type="String" />
		<cfreturn variables.attributes[arguments.key] />
	</cffunction>

	<cffunction name="setAttribute" output="false" access="private" returntype="void">
		<cfargument name="key" required="true" type="String" />
		<cfargument name="value" required="true" type="any" />
		<cfset variables.attributes[arguments.key] = arguments.value />
	</cffunction>

	<cffunction name="attributeExists" output="false" access="private" returntype="boolean">
		<cfargument name="key" required="true" type="String" />
		<cfreturn structKeyExists(variables.attributes, arguments.key) />
	</cffunction>
	
	<cffunction name="getParentTemplatePath" returntype="string" access="private" output="no">
		<cfset var cfcatch = "" />
		<cfset var i = -1 />
		<cftry>
			<cfthrow message="anything" />
			<cfcatch>
				<cfloop from="2" to="#arrayLen(cfcatch.tagContext)#" index="i">
					<cfif cfcatch.tagContext[i].template neq cfcatch.tagContext[1].template>
						<cfreturn cfcatch.tagContext[i].template />
					</cfif>
				</cfloop>
			</cfcatch>
		</cftry>
	</cffunction>
	
	
</cfcomponent>