// Atelier - Typst show rule
// The document data that Quarto and the filters give to `atelier-document`.
// A font that the page sets with `mainfont` or `codefont`, or that the brand
// sets, wins over the font of the preset.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#show: doc => atelier-document(
  (
    title: $if(title)$[$title$]$else$none$endif$,
    subtitle: $if(subtitle)$[$subtitle$]$else$none$endif$,
    // The empty block stops a date such as "24. November 2026" from becoming a list item.
    date: $if(date)$[#[]$date$]$else$none$endif$,
    duration: $if(atelier-duration)$[$atelier-duration$]$else$none$endif$,
    abstract: $if(abstract)$[$abstract$]$else$none$endif$,
    licence: $if(license.text)$[$license.text$]$elseif(license)$[$license$]$else$none$endif$,
    copyright: $if(copyright.holder)$[© $if(copyright.year)$$copyright.year$ $endif$$copyright.holder$]$elseif(copyright)$[$copyright$]$else$none$endif$,
    keywords: ($for(keywords)$"$keywords/nowrap$",$endfor$),
    lang: "$if(lang)$$lang$$else$en$endif$",
    region: $if(region)$"$region$"$else$none$endif$,
    fontsize: $if(fontsize)$$fontsize$$elseif(brand.typography.base.size)$$brand.typography.base.size$$else$none$endif$,
    linestretch: $if(linestretch)$$linestretch$$else$none$endif$,
    toc: $if(toc)$true$else$false$endif$,
    toc-title: $if(toc-title)$[$toc-title$]$else$none$endif$,
    toc-depth: $if(toc-depth)$$toc-depth$$else$3$endif$,
    numbering: $if(section-numbering)$"$section-numbering$"$else$none$endif$,
    fonts: (
      base: $if(mainfont)$("$mainfont$",)$elseif(brand.typography.base.family)$$brand.typography.base.family$$else$atelier-preset-fonts.base$endif$,
      headings: $if(brand.typography.headings.family)$$brand.typography.headings.family$$elseif(mainfont)$("$mainfont$",)$elseif(brand.typography.base.family)$$brand.typography.base.family$$else$atelier-preset-fonts.headings$endif$,
      monospace: $if(codefont)$($for(codefont)$"$codefont$",$endfor$)$elseif(brand.typography.monospace.family)$$brand.typography.monospace.family$$else$atelier-preset-fonts.monospace$endif$,
    ),
    labels: (
      authors: [$labels.authors$],
      published: [$labels.published$],
      abstract: [$labels.abstract$],
    ),
    logo: atelier-logo,
  ),
  doc,
)
