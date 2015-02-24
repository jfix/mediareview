xquery version "1.0-ml";

module namespace http="http://http";

declare namespace xhttp="xdmp:http" ;
declare namespace xeld="xdmp:encoding-language-detect" ;

declare variable $http:options := map:new((
     map:entry("verify-cert",    "false")
    ,map:entry("encoding",      ("auto", "iso-8859-1", "windows-1252", "tis-620", "euc-kr"))
));

(:~
 : Calls xdmp:encoding-language-detect() and attempts to detect the encoding of the node.
 :
 : @param $encoding as xs:string force an encoding (or "auto")
 : @param $n as node() the (binary) node to find the encoding for
 : @return the first encoding found (irrespectve of score) or the encoding submitted (and not "auto")
 :)
declare function http:get-encoding(
  $encoding as xs:string,
  $n as node())
as xs:string
{
    switch($encoding)
        case 'auto'
            return
                let $enc := xdmp:encoding-language-detect($n)[1]/xeld:encoding
                let $_ := xdmp:log("DETECTED ENCODING: " || $enc)
                
                (: ignore weird ones like windows-1252 or tis-620... :)
                return if (lower-case($enc) eq ("utf-8", "iso-8859-1", "euc-kr")) then $enc else "utf-8"
        default 
            return $encoding
};

(:~
 :
 :
 :
 :)
declare function http:get-body(
  $body as document-node()?,
  $type as xs:string,
  $encodings as xs:string*)
as node()+
{
    if (empty($body)) 
    then 
        ()
    else 
        if (empty($encodings) or $type eq 'binary') 
        then 
            $body
        else
            let $encoding := http:get-encoding($encodings[1], $body)
            let $_ := xdmp:log("USING THIS ENCODING: " || $encoding)
            return 
                try {
                    xdmp:binary-decode($body, $encoding) ! (
                        switch($type)
                            case 'text' 
                                return document { text { . } }
                            default 
                                return 
                                    try { 
                                        xdmp:unquote(.) 
                                    } catch($ex) {
                                        switch($ex/error:code)
                                            (: Bad XML. Extend as needed. :)
                                            case 'XDMP-DOCNOENDTAG' 
                                                return document { text { . } }
                                            default 
                                                return xdmp:rethrow()
                                    }
                    ) 
                } catch ($ex) {
                    switch($ex/error:code)
                        (: Decoding errors. Extend as needed. :)
                        case 'XDMP-DOCUTF8SEQ' 
                            return http:get-body($body, $type, subsequence($encodings, 2))
                        default 
                            return xdmp:rethrow() 
                }
};

(:~
 :
 :
 :
 :)
declare function http:content-type(
  $content-type as xs:string?)
as xs:string
{
    (: Figure out the node type from the content type.
     : Extend as needed.
     :)
    if (contains($content-type, 'text/xml')) 
    then 
        'xml'
    else 
        if (contains($content-type, 'text/')) 
        then 
            'text'
        else 
            'binary'
};

(:~
 : Returns the "final URL" (i.e. following 301 and 302 redirect requests)
 : @param $uri xs:string containing the initial URL
 : @return xs:string containing the final URL, or an error message
 :)
declare function http:resolve-uri(
    $uri as xs:string
) as xs:string?
{
    let $head-response := try { xdmp:http-head($uri) } catch($e) { fn:error("", "X-HTTP-HEAD", $e//*:message) }
    let $head-code := $head-response//xhttp:code
    
    return
        switch($head-code)
            case 200
                return $uri
            case 301
            case 302    
                return 
                    let $location := $head-response//xhttp:location
                    let $head-location := 
                        if ($location)
                        then
                            (: Location header should be absolute, but some servers set relative locations,
                               according to a new HTTP spec, that may be acceptable:
                               http://webmasters.stackexchange.com/questions/31274/what-are-the-consequences-for-using-relative-location-headers?answertab=votes#tab-top
                            :)
                            if (not(starts-with($location, 'http')))
                            then
                                http:get-host-from-url($uri) || "/" || replace($location, "^/+", "")
                            else
                                $location
                        else
                            ()
                        return
                            http:resolve-uri($location)
            default
                return
                    (xdmp:log("DEFAULT SWITCH CASE FOR THIS URI: " || $uri), $uri)
 };

(:~
 :
 :
 :
 :
 :)
declare function http:get-host-from-url(
    $uri as xs:string
) as xs:string?
{
    let $t := tokenize($uri, '[/\?]')
    return string-join($t[1 to 3], "/")
};

(:~
 :
 :
 :
 :
 :)
declare function http:get(
  $uri as xs:string)
as node()+
{
    http:get(
        http:resolve-uri($uri),
        $http:options
        
        (: Extend the list of fallback encodings as needed. 
            ('auto', 'iso-8859-1', 'windows-1252', 'tis-620')
        :)
    )
};

(:~
 :
 :
 :
 :)
declare function http:get(
    $uri as xs:string,
    $options as map:map)
as node()+
{
    (: binary is safe for any encoding. :)
    let $response := xdmp:http-get(
        $uri,
        <options xmlns="xdmp:http">
            <verify-cert>{map:get($options, "verify-cert")}</verify-cert>
            <format xmlns="xdmp:document-get">binary</format>
        </options>)
        let $meta := $response[1]
        return (
            $meta,
            http:get-body(
                subsequence($response, 2),
                http:content-type($meta/xhttp:headers/xhttp:content-type),
                map:get($options, "encodings")
            )
        )
};

