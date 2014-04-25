xquery version "1.0-ml";
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
if (exists(collection("id:" || $id)))
    then
        xdmp:log($name || " already exists, not saving again")
    else
        (
        xdmp:document-insert($path, $doc, (), ("provider", "id:"||$id, "language:"||$language)),
        xdmp:log($name || " saved successfully at " || $path)
        )
