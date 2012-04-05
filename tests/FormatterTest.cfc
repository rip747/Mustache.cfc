<cfcomponent extends="mxunit.framework.TestCase">

	<cffunction name="setup">
		<cfset partials = {} />
		<cfset stache = createObject("component", "mustache.MustacheFormatter").init() />
	</cffunction>

	<cffunction name="tearDown">
		<!---// make sure tests are case sensitive //--->
		<cfset assertEqualsCase(expected, stache.render(template, context, partials))/>
		<!---// reset variables //--->
		<cfset partials = {} />
		<cfset context = {} />
	</cffunction>

  <cffunction name="invalidFormatter">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{thing:XXXXXX()}}!" />
    <cfset expected = "Hello, World!" />
  </cffunction>

  <cffunction name="upperCase">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{thing:upperCase()}}!" />
    <cfset expected = "Hello, WORLD!" />
  </cffunction>

  <cffunction name="lowerCase">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{thing:lowerCase()}}!" />
    <cfset expected = "Hello, world!" />
  </cffunction>

  <cffunction name="leftPad">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, [{{thing:leftPad(20)}}]" />
    <cfset expected = "Hello, [#lJustify('World', 20)#]" />
  </cffunction>

  <cffunction name="rightPad">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, [{{thing:rightPad(20)}}]" />
    <cfset expected = "Hello, [#rJustify('World', 20)#]" />
  </cffunction>

	<cffunction name="multiply">
		<cfscript>
			context = {
				  name="Dan"
				, value=1000
			};

			template = 'Hello {{name}}! You have just won ${{value}}! Taxes are ${{value:multiply(0.2)}}!';
			expected = 'Hello Dan! You have just won $1000! Taxes are $200!';
		</cfscript>
	</cffunction>

  <cffunction name="chainedFormatters">
    <cfset context = { thing = 'World'} />
    <cfset template = "Hello, {{thing:upperCase():leftPad(20):rightPad(40)}}!" />
    <cfset expected = "Hello, #rJustify(lJustify('WORLD', 20), 40)#!" />
  </cffunction>


	<cffunction name="complexTemplate">
		<cfset var Helper = createObject("component", "tests.Helper") />
		<cfset context = Helper.getComplexContext() />
		<cfset template = Helper.getComplexFormatterTemplate() />

		<cfset expected = trim('
Please do not respond to this message. This is for information purposes only.

FOR SECURITY PURPOSES, PLEASE DO NOT FORWARD THIS EMAIL TO OTHERS.

A new ticket has been entered and assigned to Tommy.
+----------------------------------------------------------------------------+
|  Ticket: 1234                         Priority: Medium                     |
|    Name: Jenny                           Phone: 867-5309                   |
| Subject: E-mail not working                                                |
+----------------------------------------------------------------------------+
Description:
Here''s a description

with some

new lines
		') />
	</cffunction>

	<cffunction name="complexTemplateRev2">
		<cfset var Helper = createObject("component", "tests.Helper") />
		<cfset context = Helper.getComplexContext() />

		<!---// change context //--->
		<cfset context.Settings.EnableEmailUpdates = false />
		<cfset context.Assignee.Name = "" />
		<cfset context.Ticket.Note = "" />
		<cfset context.Ticket.Description = "" />

		<cfset template = Helper.getComplexFormatterTemplate() />
		<cfset expected = trim('
FOR SECURITY PURPOSES, PLEASE DO NOT FORWARD THIS EMAIL TO OTHERS.

A new ticket has been entered and is UNASSIGNED.
+----------------------------------------------------------------------------+
|  Ticket: 1234                         Priority: Medium                     |
|    Name: Jenny                           Phone: 867-5309                   |
| Subject: E-mail not working                                                |
+----------------------------------------------------------------------------+
') />
	</cffunction>

</cfcomponent>