xquery version "1.0-ml";

module namespace f="http://marklogic.com/appservices/utils/normalize-dates";

declare variable $MONTHS := map:new((
    map:entry("jan", "01"),
    map:entry("feb", "02"),
    map:entry("mar", "03"),
    map:entry("apr", "04"),
    map:entry("may", "05"),
    map:entry("jun", "06"),
    map:entry("jul", "07"),
    map:entry("aug", "08"),
    map:entry("sep", "09"),
    map:entry("oct", "10"),
    map:entry("nov", "11"),
    map:entry("dec", "12")
));

declare variable $FORMATS := map:new((
    map:entry("^[01]\d/[0-3]\d/\d\d\d\d$", "fix-mm-dd-yyyy"),
    map:entry("^[0-3]\d/[01]\d/\d\d\d\d$", "fix-dd-mm-yyyy"),
    map:entry("^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+[+-]\d\d\d\d$", 
        "fix-day-dd-mon-yyyy-hh-mm-ss-tz"),
    map:entry("^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+[+-]\d\d:\d\d$",
        "fix-day-dd-mon-yyyy-hh-mm-ss-tz"),
    map:entry("^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+...$",
        "fix-day-dd-mon-yyyy-hh-mm-ss-tz")
        
    (: TODO: provide more ... :)
));

declare function f:normalize-datetime(
    $dt as xs:string,
    $re as xs:string
) as xs:dateTime
{
    let $func := xdmp:function(fn:QName("http://marklogic.com/appservices/utils/normalize-dates", f:convf($re)))
(:    return f:convf($re):)
    return $func($dt)
};

(: private functions :)

declare %private function f:convf(
    $re as xs:string
)
{
    if  (map:contains($FORMATS, $re))
    then
        map:get($FORMATS, $re)
    else
        error(xs:QName('f:BADREGEX'), 'FATAL: Unknown date format regex: ' || $re)
};

declare %private function f:fix-day-dd-mon-yyyy-hh-mm-ss-tz(
    $dt as xs:string
) as xs:dateTime
{
    let $parts := tokenize($dt, '\s+')
    let $day := fn:format-number(xs:integer($parts[2]), '00')
    let $month := map:get($MONTHS, lower-case(substring($parts[3], 1, 3)))
    let $time := if (string-length($parts[5]) = 7)
        then concat('0', $parts[5])
        else $parts[5]
    (: $parts[6] can be "GMT", +0000, -00:00, "Z" ... :)
    let $tz :=
        if ($parts[6] = 'GMT')
        then ''
        else
            if (contains($parts[6], ':'))
            then $parts[6]
            else concat(substring($parts[6], 1, 3), ':', substring($parts[6], 4, 6))
    
    return
        fn:dateTime(
            xs:date($parts[4] || '-' || $month || '-' || $day), 
            xs:time($time || $tz)
        )
        
};

declare %private function f:fix-dd-mm-yyyy(

) as xs:date
{
    () (: TODO :)
};
