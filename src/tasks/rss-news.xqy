xquery version "1.0-ml";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";

let $q := "oecd"
let $u := "https://news.google.com/news/feeds?pz=1&amp;cf=all&amp;ned=us&amp;hl=en&amp;output=rss&amp;q=oecd"
let $dt := current-dateTime()

let $d := xdmp:http-get($u)[2]

return 
  for $item in $d//item
    let $guid := $item/guid/string()
    let $id := substring(xdmp:md5($guid), 1, 7)
    let $uri := string-join(
      ("/news", 
      format-dateTime($dt, "[Y0001]"),
      format-dateTime($dt, "[M01]"),
      format-dateTime($dt, "[D01]"),
      $id), "/"
    ) || ".xml"
    
    let $doc := <news-item query="{$q}" guid="{$guid}" id="{$id}">
      <title>{ functx:substring-before-last($item/title, " - ") }</title>
      <provider>{ functx:substring-after-last($item/title, " - ") }</provider>
      <link>{ xdmp:url-decode(functx:substring-after-last($item/link, "url=")) }</link>
      <date>{ $item/pubDate/text() }</date>
      <content>
        <text-only>{
            normalize-space(string-join(
                xdmp:unquote($item/description/text(), (), ("repair-full", "format-xml"))//text()
            , " "))
        }</text-only>
        <full-html>{ xdmp:unquote($item/description/text(), (), ("repair-full", "format-xml")) }</full-html>
    </content>
    </news-item>
    
    return 
      if (exists(collection("id:" || $id)))
      then
        xdmp:log("item " || $id || " already exists, not re-inserting")
      else
        xdmp:document-insert(
          $uri,
          $doc,
          xdmp:default-permissions(),
          ("id:" || $id, "news-item", "status:imported", tokenize($q, " ") ! concat("query:",.))
        )