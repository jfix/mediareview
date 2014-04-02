<?xml version="1.0" encoding="utf-8"?>

<!-- Copyright 2002-2013 MarkLogic Corporation.  All Rights Reserved. -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:f="http://marklogic.com/appservices/utils/normalize-dates"
                xmlns:fp="http://marklogic.com/appservices/utils/normalize-dates/private"
                xmlns:xdmp="http://marklogic.com/xdmp"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="f xdmp xs"
                extension-element-prefixes="xdmp"
                version="2.0">

<!-- This module defines two functions:

     f:normalize-dates($dt)
     f:normalize-dates($dt,$regex)

     and a single parameter

     $f:format-regex

     Each function converts a string into an xs:date or xs:dateTime,
     if possible. The former function uses the value of the
     $f:format-regex parameter to define the regex. Because you can only
     have one value for a parameter, the second function allows you to pass
     the regex in. The advantage of the former is that the computation based
     on the regex can be performed once at "compile" time.

     If the string passed can be converted into an xs:date or xs:dateTime, then
     the string value of that typed value is returned, otherwise, the original
     string is returned unchanged.

     In theory, if the string matches the regex, it should always be possible
     to convert it to a typed value, but there's no (convenient) way to
     forbid dates like "Feb 31" via the regex.

     N.B. The stylesheet will raise fn:error(f:BADREGEX) if it doesn't recognize
     the regex. This means that even if you want to use the second form of the
     function, you must still initialize f:format-regex to some reasonable value.
-->


<xsl:param name="f:format-regex" select="()"/>

<xsl:variable name="fp:convf" as="xs:string"
              select="if (empty($FORMATS[@regex=$f:format-regex]/@function))
                      then error(xs:QName('f:BADREGEX'),
                                 concat('FATAL: Unknown date format regex: ', $f:format-regex))
                      else $FORMATS[@regex=$f:format-regex]/@function"/>

<xsl:variable name="fp:fname"
              select="QName('http://marklogic.com/appservices/utils/normalize-dates/private', $fp:convf)"
              as="xs:QName"/>

<xsl:variable name="MONTHS" as="element()+">
  <month name="jan">01</month>
  <month name="feb">02</month>
  <month name="mar">03</month>
  <month name="apr">04</month>
  <month name="may">05</month>
  <month name="jun">06</month>
  <month name="jul">07</month>
  <month name="aug">08</month>
  <month name="sep">09</month>
  <month name="oct">10</month>
  <month name="nov">11</month>
  <month name="dec">12</month>
</xsl:variable>

<xsl:variable name="FORMATS" as="element()+">
  <format regex="^[01]\d/[0-3]\d/\d\d\d\d$"   function="fix-mm-dd-yyyy"/>
  <format regex="^[0-3]\d/[01]\d/\d\d\d\d$"   function="fix-dd-mm-yyyy"/>
  <format regex="^[01]\d-[0-3]\d-\d\d\d\d$"   function="fix-mm-dd-yyyy"/>
  <format regex="^[0-3]\d-[01]\d-\d\d\d\d$"   function="fix-dd-mm-yyyy"/>
  <format regex="^[01]\d\.[0-3]\d\.\d\d\d\d$" function="fix-mm-dd-yyyy"/>
  <format regex="^[0-3]\d\.[01]\d\.\d\d\d\d$" function="fix-dd-mm-yyyy"/>
  <format regex="^\d\d\d\d[01]\d[0-3]\d$"     function="fix-yyyymmdd"/>
  <format regex="^\d\d\d\d/[01]\d/[0-3]\d$"   function="fix-yyyy-mm-dd"/>
  <format regex="^\d\d\d\d-[01]\d-[0-3]\d$"   function="fix-yyyy-mm-dd"/>
  <format regex="^\d\d\d\d[01]\d[0-3]\dT[0-2]\d[0-6]\d[0-6]\d$"
          function="fix-yyyymmddthhmmss"/>
  <format regex="^[0-3]\d/[0-3]\d/\d\d\d\d-[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-dd-mm-yyyy-hh-mm-ss"/>
  <format regex="^[0-3]\d/[0-3]\d/\d\d\d\d\s[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-dd-mm-yyyy-hh-mm-ss"/>
  <format regex="^\d\d\d\d/[01]\d/[0-3]\d-[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-yyyy-mm-dd-hh-mm-ss"/>
  <format regex="^\d\d\d\d-[01]\d-[0-3]\d-[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-yyyy-mm-dd-hh-mm-ss"/>
  <format regex="^\d\d\d\d/[01]\d/[0-3]\d\s[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-yyyy-mm-dd-hh-mm-ss"/>
  <format regex="^\d\d\d\d-[01]\d-[0-3]\d\s[0-2]\d:[0-6]\d:[0-6]\d$"
          function="fix-yyyy-mm-dd-hh-mm-ss"/>
  <format regex="^... [0-3]?\d,\s\d\d\d\d$" function="fix-mon-dd-yyyy"/>
  <format regex="^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+[+-]\d\d\d\d$"
          function="fix-day-dd-mon-yyyy-hh-mm-ss-tz"/>
  <format regex="^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+[+-]\d\d:\d\d$"
          function="fix-day-dd-mon-yyyy-hh-mm-ss-tz"/>
  <format regex="^[0-3]?\d\s...\s\d\d\d\d$" function="fix-dd-mon-yyyy"/>
  <format regex="^[0-3]?\d-...-\d\d\d\d$" function="fix-dd-mon-yyyy"/>
</xsl:variable>

<xsl:template match="*|@*">
    <xsl:apply-templates/>
</xsl:template>
    
<xsl:template match="text()">
    <xsl:value-of select="f:normalize-datetime(string(.), $f:format-regex)"/>
<!--    <xsl:value-of select="string(.) instance of xs:string"/>-->
</xsl:template>
    
<xsl:function name="fp:fix-mm-dd-yyyy">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:value-of
      select="concat(substring($dt,7,4),'-',substring($dt,1,2),'-',substring($dt,4,2))"/>
</xsl:function>

<xsl:function name="fp:fix-dd-mm-yyyy">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:value-of
      select="concat(substring($dt,7,4),'-',substring($dt,4,2),'-',substring($dt,1,2))"/>
</xsl:function>

<xsl:function name="fp:fix-mon-dd-yyyy">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="month" select="$MONTHS[@name=lower-case(substring($dt,1,3))]"/>
  <xsl:variable name="daystr"
                select="replace($dt,'^... ([0-3]?\d).*$', '$1')"/>
  <xsl:variable name="day" select="format-number(xs:int($daystr), '00')"/>
  <xsl:variable name="yearstr"
                select="replace($dt,'^... \d?\d,\s(\d+)', '$1')"/>
  <xsl:value-of select="concat($yearstr, '-', $month, '-', $day)"/>
</xsl:function>

<xsl:function name="fp:fix-yyyy-mm-dd">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:value-of select="concat(substring($dt,1,4),'-',substring($dt,6,2),'-',substring($dt,9,2))"/>
</xsl:function>

<xsl:function name="fp:fix-dd-mm-yyyy-hh-mm-ss">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="date"
                select="concat(substring($dt,7,4),'-',substring($dt,4,2),'-',substring($dt,1,2))"/>
  <xsl:variable name="time"
                select="concat(substring($dt,12,2),':',substring($dt,15,2),':',substring($dt,18,2))"/>

  <xsl:value-of select="concat($date,'T',$time)"/>
</xsl:function>

<xsl:function name="fp:fix-yyyy-mm-dd-hh-mm-ss">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="date"
                select="concat(substring($dt,1,4),'-',substring($dt,6,2),'-',substring($dt,9,2))"/>
  <xsl:variable name="time"
                select="concat(substring($dt,12,2),':',substring($dt,15,2),':',substring($dt,18,2))"/>

  <xsl:value-of select="concat($date,'T',$time)"/>
</xsl:function>

<xsl:function name="fp:fix-yyyymmdd">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:value-of select="concat(substring($dt,1,4),'-',substring($dt,5,2),'-',substring($dt,7,2))"/>
</xsl:function>

<xsl:function name="fp:fix-yyyymmddthhmmss">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="date"
                select="concat(substring($dt,1,4),'-',substring($dt,5,2),'-',substring($dt,7,2))"/>
  <xsl:variable name="time"
                select="concat(substring($dt,10,2),':',substring($dt,12,2),':',substring($dt,14,2))"/>

  <xsl:value-of select="concat($date,'T',$time)"/>
</xsl:function>

<xsl:function name="fp:fix-day-dd-mon-yyyy-hh-mm-ss-tz">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="parts" select="tokenize($dt, '\s+')"/>
  <xsl:variable name="day" select="format-number(xs:integer($parts[2]), '00')"/>
  <xsl:variable name="month" select="$MONTHS[@name=lower-case(substring($parts[3],1,3))]"/>
  <xsl:variable name="time"
                select="if (string-length($parts[5]) = 7) then concat('0',$parts[5]) else $parts[5]"/>
  <xsl:variable name="tz"
                select="if (contains($parts[6], ':'))
                        then $parts[6]
                        else concat(substring($parts[6],1,3),':',substring($parts[6],4,6))"/>
    <xsl:message>just saying hello...</xsl:message>
  <xsl:value-of select="concat($parts[4],'-',$month,'-',$day,'T',$time,$tz)"/>
</xsl:function>

<xsl:function name="fp:fix-dd-mon-yyyy">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="parts" select="tokenize($dt, '[-\s]')"/>
  <xsl:variable name="day"   select="format-number(xs:integer($parts[1]), '00')"/>
  <xsl:variable name="month" select="$MONTHS[@name=lower-case($parts[2])]"/>
  <xsl:value-of select="concat($parts[3],'-',$month,'-',$day)"/>
</xsl:function>

<xsl:function name="f:normalize-datetime">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:variable name="converted">
    <xdmp:try>
      <xsl:choose>
        <!-- HACK!!! -->
        <xsl:when test="contains($fp:convf, 'hh')">
          <xsl:value-of select="xs:dateTime(xdmp:apply(xdmp:function($fp:fname), $dt))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="xs:date(xdmp:apply(xdmp:function($fp:fname), $dt))"/>
        </xsl:otherwise>
      </xsl:choose>
      <xdmp:catch name="e">
        <!--<xsl:message><xsl:sequence select="$e"/></xsl:message>-->
        <xsl:value-of select="$dt"/>
      </xdmp:catch>
    </xdmp:try>
  </xsl:variable>
  <xsl:value-of select="string($converted)"/>
</xsl:function>

<xsl:function name="f:normalize-datetime">
  <xsl:param name="dt" as="xs:string"/>
  <xsl:param name="format-regex" as="xs:string"/>


  <xsl:variable name="convf" as="xs:string"
                select="if (empty($FORMATS[@regex=$format-regex]/@function))
                        then error(xs:QName('f:BADREGEX'),
                                   concat('FATAL: Unknown date format regex: ', $format-regex))
                        else $FORMATS[@regex=$format-regex]/@function"/>

  <xsl:variable name="fname"
                select="QName('http://marklogic.com/appservices/utils/normalize-dates/private', $convf)"
                as="xs:QName"/>
    
    <xsl:message>dt: <xsl:value-of select="$dt"/></xsl:message>
    <xsl:message>regex: <xsl:value-of select="$f:format-regex"/></xsl:message>
    <xsl:message>fname: <xsl:value-of select="$fname"/></xsl:message>

  <xsl:variable name="converted">
    <xdmp:try>
      <xsl:choose>
        <!-- HACK!!! -->
        <xsl:when test="contains($convf, 'hh')">
          <xsl:value-of select="xs:dateTime(xdmp:apply(xdmp:function($fname), $dt))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="xs:date(xdmp:apply(xdmp:function($fname), $dt))"/>
        </xsl:otherwise>
      </xsl:choose>
      <xdmp:catch name="e">
        <xsl:message><xsl:sequence select="$e"/></xsl:message>
        <xsl:value-of select="concat('Could not convert this date: ', $dt)"/>
      </xdmp:catch>
    </xdmp:try>
  </xsl:variable>
  <xsl:value-of select="string($converted)"/>
</xsl:function>

</xsl:stylesheet>
