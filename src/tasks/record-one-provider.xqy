xquery version "1.0-ml";

(:~
 : This module gets called by another one and records
 : a provider XML document (if this provider doesn't
 : already exist).
 :
 :)
 
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare variable $item as document-node() external;

(: find items we want to record for a news provider :)
let $news-item := $item/news-item
let $link := u:extract-host-from-url($news-item/link)
let $id := u:create-provider-id($news-item)
let $name := replace($news-item/provider, "&amp;", "&amp;amp;")
let $language := $news-item/language/text()
let $path := "/providers/" || substring($id, 1, 2) || "/" || substring($id, 3) || ".xml"

(: create the initial document for the news provider :)
let $doc := <provider id="{$id}">
    <link>{$link}</link>
    <name>{$name}</name>
    <language>{$language}</language>
</provider>

(: store the document of the news provider, unless it exists already :)
return
if (not(exists(collection("id:" || $id))))
    then
        (
            xdmp:document-insert(
                $path, 
                $doc, 
                $u:default-permissions, 
                ("provider", "id:"||$id, "language:"||$language)
            ),
            xdmp:log($name || " saved successfully at " || $path),
            xdmp:document-add-collections(xdmp:node-uri($item), ("provider-extracted")),
            u:record-event(
                u:create-event(
                    "provider-bot", 
                    "provider successfully extracted", 
                    (
                        <type>provider-extracted</type>,
                        <result>success</result>,
                        <provider-name>{$name}</provider-name>,
                        <provider-id>{$id}</provider-id>,
                        <newsitem-id>{$news-item/@id}</newsitem-id>
                    )
                )
            )
        )
    else ()

