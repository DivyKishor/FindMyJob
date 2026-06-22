<cfcomponent output="false">
	<!---
		AlertChannel — Phase 2, PR 2.4.

		Base class / interface contract for alert delivery channels.
		Extend this component to add a new channel (Telegram, WhatsApp, email, …).

		The only required method is send(alertPayload).  Each channel is responsible
		for its own error handling so one failing channel does not block others.

		Sub-classes also have access to:
		  variables.channelName — string tag used in logs and dedupe keys.
		  variables.enabled     — false if the channel is misconfigured; callers check this.

		Tag syntax only (project standard).
	--->

	<cfset variables.channelName = "base" />
	<cfset variables.enabled     = true />

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfreturn this />
	</cffunction>

	<cffunction name="getChannelName" access="public" returntype="string" output="false">
		<cfreturn variables.channelName />
	</cffunction>

	<cffunction name="isEnabled" access="public" returntype="boolean" output="false">
		<cfreturn variables.enabled />
	</cffunction>

	<!---
		send( alertPayload )
		  Deliver a single alert.  alertPayload is a struct with at least:
		    job_id, company_id, company_name, title, location, link, score, reasons.
		  Returns a struct: { sent: boolean, error: string }.
		  Subclasses MUST override this method.
	--->
	<cffunction name="send" access="public" returntype="struct" output="false">
		<cfargument name="alertPayload" type="struct" required="true" />
		<!--- Base class is a no-op; overridden by concrete channels. --->
		<cfreturn { sent: false, error: "AlertChannel.send() not implemented by subclass" } />
	</cffunction>

</cfcomponent>
