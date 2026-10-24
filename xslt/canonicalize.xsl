<?xml version="1.0"?>
<!--
Copyright (C) 2026 AHMAD ALI PARR
Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
Project a canvas record down to the semantic certificate.
The bootstrap applies this projection in perl/SCM/Pipeline.pm
because xsltproc is not part of the running environment.
The stylesheet is terminating: one template, no recursion on node identity.
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="UTF-8" omit-xml-declaration="no"/>
  <xsl:strip-space elements="*"/>
  <xsl:template match="/scm">
    <scm v="1">
      <intent><xsl:value-of select="intent"/></intent>
      <workspace><xsl:value-of select="workspace"/></workspace>
      <invariant><xsl:value-of select="invariant"/></invariant>
    </scm>
  </xsl:template>
  <xsl:template match="text()"/>
</xsl:stylesheet>
