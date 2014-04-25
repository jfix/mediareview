<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all"
    version="2.0">

    <xsl:template match="news-item">
        <html>
            <head>
                <title><xsl:value-of select="provider"/>: <xsl:value-of select="title"/></title>
            </head>
            <body>
                <div class="news-item" id="news-item-{@id}">
                    <div class="title"><xsl:value-of select="title"/></div>
                    <div class="provider"><xsl:value-of select="provider"/></div>
                    <div class="pub-date"><xsl:value-of select="normalized-date"/></div>
                    <div class="pub-time"><xsl:value-of select="normalized-date/@time"/></div>
                    <div class="link"><a href="{link}"><xsl:value-of select="link"/></a></div>
                    <div class="abstract">
                        <xsl:value-of select="content/text-only"/>
                    </div>
                    <div class="language">
                        <xsl:value-of select="language"/>
                    </div>
                    <div class="screenshot">
                        <img src="/api/news-items/{@id}/screenshot" alt="screenshot"/>
                    </div>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
