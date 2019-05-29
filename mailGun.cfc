component {

	function init(
		required string apiKey
	,	required string publicKey
	,	string apiUrl= "https://api.mailgun.net/v2"
	,	string defaultDomain= ""
	,	numeric httpTimeOut= 120
	,	boolean debug= ( request.debug ?: false )
	) {
		this.apiKey= arguments.apiKey;
		this.publicKey= arguments.publicKey;
		this.apiUrl= arguments.apiUrl;
		this.defaultDomain= arguments.defaultDomain;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug= arguments.debug;
		return this;
	}

	function debugLog(required input) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "mailgun: " & arguments.input );
			} else {
				request.log( "mailgun: (complex type)" );
				request.log( arguments.input );
			}
		} else if ( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="mailgun", type="information" );
		}
		return;
	}

	struct function validate( required string address ) {
		this.debugLog( "validate" );
		return this.apiRequest( api="GET address/validate", apiKey= this.publicKey, address= arguments.address );
	}

	struct function getLogs( string domain= this.defaultDomain, numeric limit= 100, numeric skip= 0 ) {
		this.debugLog( "getLogs" );
		return this.apiRequest( api="GET #arguments.domain#/log", argumentCollection= arguments );
	}

	struct function getStats( string domain= this.defaultDomain, event= "", date startDate, numeric limit= 100, numeric skip= 0 ) {
		this.debugLog( "getStats" );
		if ( structKeyExists( arguments, "startDate" ) ) {
			arguments[ "start-date" ]= dateFormat( arguments.startDate, "YYYY-MM-DD" );
			structDelete( arguments, "startDate" );
		}
		return this.apiRequest( api="GET #arguments.domain#/stats", argumentCollection= arguments );
	}

	struct function getRoutes( numeric limit= 100, numeric skip= 0 ) {
		this.debugLog( "getRoutes" );
		return this.apiRequest( api="GET routes", argumentCollection= arguments );
	}

	struct function getRoute( required string id ) {
		this.debugLog( "getRoutes" );
		return this.apiRequest( api="GET routes/#arguments.id#" );
	}

	struct function createRoute( required expression, required action, string priority= 0, string description ) {
		this.debugLog( "createRoute" );
		return this.apiRequest( api="POST routes", argumentCollection= arguments );
	}

	struct function updateRoute( required string id, required expression, required action, string priority= 0, string description ) {
		this.debugLog( "updateRoute" );
		return this.apiRequest( api="PUT routes/#arguments.id#", argumentCollection= arguments );
	}

	struct function deleteRoute( required string id ) {
		this.debugLog( "deleteRoute" );
		return this.apiRequest( api="DELETE routes/#arguments.id#" );
	}

	struct function getMailboxes( string domain= this.defaultDomain, numeric limit= 100, numeric skip= 0 ) {
		this.debugLog( "getMailboxes" );
		return this.apiRequest( api="GET #arguments.domain#/mailboxes", argumentCollection= arguments );
	}

	struct function createMailbox( string domain= this.defaultDomain, required string mailbox, required string password ) {
		this.debugLog( "createMailboxe" );
		return this.apiRequest( api="POST #arguments.domain#/mailboxes", argumentCollection= arguments );
	}

	struct function updateMailbox( string domain= this.defaultDomain, required string mailbox, required string password ) {
		this.debugLog( "updateMailbox #arguments.mailbox#" );
		return this.apiRequest( api="PUT #arguments.domain#/mailboxes/#arguments.mailbox#", argumentCollection= arguments );
	}

	struct function deleteMailbox( string domain= this.defaultDomain, required string mailbox ) {
		this.debugLog( "deleteMailbox #arguments.mailbox#" );
		return this.apiRequest( api="DELETE #arguments.domain#/mailboxes/#arguments.mailbox#" );
	}

	struct function sendMail( string domain= this.defaultDomain, required to, required from, required subject, string text, string html ) {
		var item= "";
		this.debugLog( "Send mail with mailGun" );
		for ( item in arguments ) {
			if ( listFind( "v_,h_,o_", left( item, 2 ) ) ) {
				arguments[ replace( reReplace( item, "^(v|h|o)_", "\1:" ), "_", "-", "all" ) ]= arguments[ item ];
				structDelete( arguments, item );
			}
		}
		var req= this.apiRequest( api="POST #arguments.domain#/messages", argumentCollection= arguments );
		return req;
	}

	struct function apiRequest( required string api ) {
		var http= 0;
		var item= "";
		var x= 0;
		var out= {
			requestUrl= this.apiUrl & "/" & listRest( arguments.api, " " )
		,	verb= listFirst( arguments.api, " " )
		,	success= false
		,	error= ""
		,	status= ""
		,	statusCode= 0
		,	response= ""
		};
		var paramVerb= ( requestVerb == "GET" ? "url" : "formfield" );
		structDelete( arguments, "id" );
		structDelete( arguments, "api" );
		structDelete( arguments, "domain" );
		structDelete( arguments, "apiKey" );
		this.debugLog( "mailGun: #out.verb# #out.requestUrl#" );
		if ( this.debug ) {
			this.debugLog( arguments );
			this.debugLog( out );
		}
		cfhttp( result="http", url=out.requestUrl, method=out.verb, charset="utf-8", throwOnError=false, timeOut=this.httpTimeOut, username="api", password= ( arguments.apiKey ?: this.apiKey ) ) {
			for ( item in arguments ) {
				if ( isArray( arguments[ item ] ) ) {
					for ( x in arguments[ item ] ) {
						cfhttpparam( name=lCase( item ), type=paramVerb, value=x );
					}
				} else if ( isSimpleValue( arguments[ item ] ) ) {
					cfhttpparam( name=lCase( item ), type=paramVerb, value=arguments[ item ] );
				}
			}
		}
		// this.debugLog( response )
		out.response= toString( http.fileContent );
		this.debugLog( out.response );
		//  RESPONSE CODE ERRORS 
		if ( !structKeyExists( http, "responseHeader" ) || !structKeyExists( http.responseHeader, "Status_Code" ) ) {
			out.success= false;
		} else if ( http.responseHeader.Status_Code == "401" ) {
			//  unauthorized 
			out.success= false;
		} else if ( http.responseHeader.Status_Code == "422" ) {
			//  unprocessable 
			out.success= false;
		} else if ( http.responseHeader.Status_Code == "500" ) {
			//  server error 
			out.success= false;
		} else if ( listFind( "4,5", left( http.responseHeader.Status_Code, 1 ) == "4" ) ) {
			//  unknown error 
			out.success= false;
		} else if ( http.responseHeader.Status_Code == "" ) {
			//  donno 
			out.success= false;
		} else if ( http.responseHeader.Status_Code == "200" ) {
			//  out.success 
			out.success= true;
		}
		//  parse response 
		try {
			if ( left( http.responseHeader[ "Content-Type" ], 16 ) == "application/json" ) {
				out.response= deserializeJSON( out.response );
			} else {
				out.error= "Invalid response type: " & http.responseHeader[ "Content-Type" ];
			}
		} catch (any cfcatch) {
			out.error= "JSON Error: " & cfcatch.message;
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		return out;
	}

}