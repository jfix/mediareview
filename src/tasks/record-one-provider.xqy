xquery version "1.0-ml";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";

declare variable $item as document-node() external;

(: find items we want to record for a news provider :)
let $link := u:extract-host-from-url($item/news-item/link)
let $name := replace($item//provider, "&amp;", "&amp;amp;")
let $id := substring(xdmp:md5($link), 1, 9)
let $language := $item/news-item/language/text()
let $path := "/providers/" || substring($id, 1, 2) || "/" || substring($id, 3) || ".xml"

(: create the initial document for the news provider :)
let $doc := <provider id="{$id}">
    <link>{$link}</link>
    <name>{$name}</name>
    <language>{$language}</language>
</provider>

(: store the document of the news provider, unless it exists already :)
return
if (exists(collection("id:" || $id)))
    then
        xdmp:log($name || " already exists, not saving again")
    else
        (
        xdmp:document-insert($path, $doc, (), ("provider", "id:"||$id, "language:"||$language)),
        xdmp:log($name || " saved successfully at " || $path)
        )
