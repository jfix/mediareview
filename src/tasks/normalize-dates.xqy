xquery version "1.0-ml";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "/src/lib/xquery/normalize-dates.xqm";

declare variable $regex:= "^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+...$";

for $item in collection("news-item")//news-item[not(normalized-date)]
    let $date := $item/date
    let $normalized-date := <normalized-date>{nd:normalize-datetime($date, $regex)}</normalized-date>
    return
(:        $normalized-date:)
        xdmp:node-insert-after($date, $normalized-date)