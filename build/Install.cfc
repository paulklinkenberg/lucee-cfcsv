<cfcomponent output="no">
<!---
Version 1.2 of the Lucee tag and function Extension installer
By Paul Klinkenberg, www.lucee.nl
--->

	<cfset variables.projectName = "{label}" />
	<cfset variables.libraryType = "tag" /><!---  tag / function --->

	
	<cffunction name="validate" returntype="void" output="no" hint="called to validate the entered data">
		<cfargument name="error" type="struct" required="yes" />
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="config" type="struct" required="yes" />
		<cfargument name="step" type="numeric" required="yes" />
	</cffunction>


	<cffunction name="update" returntype="string" access="public" output="no" hint="called from Lucee to update application">
		<!--- this is rude to do. But it's also rude not to have another option. --->
		<cfset structDelete(application, "plugin", false) />
		<cfset var sReturn = "" />
		
		<cfset install(argumentCollection=arguments) />
		<cfsavecontent variable="sReturn"><cfoutput>
			<h3>Updated!</h3>
			<p>#variables.projectName# is now updated.</p>
			<p>&nbsp;</p>
		</cfoutput></cfsavecontent>
		<cfreturn sReturn />
	</cffunction>
	
	
	<cffunction name="install" returntype="string" access="public" output="no" hint="called from Lucee to install application">
		<cfargument name="error" type="struct" required="yes" />
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="config" type="struct" required="yes" />
		<cfset var allformdata = config.mixed />
		<cfset var sReturn = "" />
		<!---/Applications/tomcat/lucee/lucee-server/context/gateway/lucee/extension/gateway--->
		<cfset var savePath = rereplaceNoCase(arguments.path, "^zip:[/\\]{2}(.*?[/\\])extensions[/\\].+", "\1") />
		<cfif savePath eq arguments.path>
			<cfthrow message="The lucee server/web root path could not be determined. This means the clumsy script writer did something wrong. Please let him know about this, with the following data: path='#arguments.path#', file Install.cfc, function install()" />
		</cfif>
		
		<!--- create a new directory for the code files --->
		<cfset savePath &= "library#server.separator.file##variables.libraryType##server.separator.file#" />
		<cfif not directoryExists(savepath)>
			<cfthrow message="The path #savePath# should exist, but doesn't!" />
		</cfif>
		
		<!--- save the path in the config, so we can use it when uninstalling --->
		<cfset allformdata.savePath = savePath />
		
		<!--- add the cfc to the lucee root path --->
		<cfzip action="unzip" file="#arguments.path#thecode.zip"
		destination="#savepath#" overwrite="yes" />
		
		<!---  clear the tag/function cache --->
		<cfif not structKeyExists(server, "railo") or server.railo.version gte "3.3.0.005">
			<cfset systemCacheClear(variables.libraryType) />
		</cfif>
		
		<cfsavecontent variable="sReturn"><cfoutput>
			<h3>Installed!</h3>
			<p>The #variables.projectName# is now installed.</p>
		</cfoutput></cfsavecontent>
		<cfreturn sReturn />
	</cffunction>


	<cffunction name="uninstall" returntype="string" output="no" hint="called by Lucee to uninstall the application">
		<cfargument name="path" type="string" />
		<cfargument name="config" type="struct" />
		<cfset var allformdata = arguments.config.mixed />
		<cfset var errors = [] />
		<cfset var qDirsAndFiles = "" />
		<cfdirectory action="list" name="qDirsAndFiles" directory="#arguments.path#thecode.zip" recurse="yes" sort="name DESC, dir DESC" />
		<!---  remove the files and directories --->
		<cfloop query="qDirsAndFiles">
			<cfset var installedpath = allformdata.savePath & rereplaceNoCase(qDirsAndFiles.directory, ".+\.zip", "") & qDirsAndFiles.name />
			<cftry>
				<cfif qDirsAndFiles.type eq "file" and fileExists(installedpath)>
					<cffile action="delete" file="#installedpath#" />
				<cfelseif directoryExists(installedpath)>
					<cfdirectory action="delete" directory="#installedpath#" recurse="yes" />
				</cfif>
				<cfcatch>
					<cfset arrayAppend(errors, cfcatch.message & " " & cfcatch.detail) />
				</cfcatch>
			</cftry>
		</cfloop>
		
		<cfset var ret = "<strong>You have now uninstalled the #variables.projectName#</strong>.<br />
			Was there a problem with the #variables.libraryType#? Then please let me know at <a href='mailto:paul@ongevraagdadvies.nl'>paul@ongevraagdadvies.nl</a>" />
			
		<cfif arrayLen(errors)>
			<cfset ret &= "<br /><br />One or more errors were reported while uninstalling."
				& "<br />The errors:<ul><li>#arrayToList(errors, '</li><li>')#</li></ul>" />
		</cfif>
		<cfreturn ret />
	</cffunction>

</cfcomponent>