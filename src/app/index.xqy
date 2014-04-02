xquery version "1.0-ml";
(:import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";:)
(:declare namespace html = "http://www.w3.org/1999/xhtml";:)
declare option xdmp:output "media-type=text/html";

<html>
    <head></head>
    <body><p>{
        count(collection("news-item")//news-item)
        } items</p>
        <div>
            <ul>{
            for $item in collection("news-item")//news-item
            return 
                <li>
                    {$item/date}: <a href="{$item//link}">{ $item/title || " - " || $item/provider}</a>
                
                </li>
            }</ul>
        </div>
    </body>
</html>
