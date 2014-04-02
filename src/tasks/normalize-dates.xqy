xquery version "1.0-ml";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "/src/tasks/normalize-dates.xqm";

let $date := "Mon, 31 Mar 2014 12:14:48 GMT"
let $regex:= "^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+..."

return nd:normalize-datetime($date, $regex)