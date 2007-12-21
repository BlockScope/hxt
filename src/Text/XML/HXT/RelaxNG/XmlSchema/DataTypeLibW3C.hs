-- ------------------------------------------------------------

{- |
   Module     : Text.XML.HXT.RelaxNG.XmlSchema.DataTypeLibW3C
   Copyright  : Copyright (C) 2005 Uwe Schmidt
   License    : MIT

   Maintainer : Uwe Schmidt (uwe@fh-wedel.de)
   Stability  : experimental
   Portability: portable
   Version    : $Id$

   Datatype library for the W3C XML schema datatypes

-}

-- ------------------------------------------------------------

module Text.XML.HXT.RelaxNG.XmlSchema.DataTypeLibW3C
  ( w3cNS
  , w3cDatatypeLib
  , xsd_NCName
  , xsd_anyURI
  , xsd_QName
  , xsd_string
  , xsd_length
  , xsd_maxLength
  , xsd_minLength
  , xsd_pattern
  , xsd_enumeration
  )
where

import Text.XML.HXT.RelaxNG.DataTypeLibUtils  

import Network.URI
  ( isURIReference )

import Text.XML.HXT.DOM.NamespacePredicates
  ( isWellformedQualifiedName
  , isNCName
  )

import Text.XML.HXT.RelaxNG.XmlSchema.Regex
    ( match )
import Text.XML.HXT.RelaxNG.XmlSchema.RegexParser
    ( parseRegex )

import Data.Maybe
  
-- ------------------------------------------------------------

-- | Namespace of the W3C XML schema datatype library
w3cNS	:: String
w3cNS	= "http://www.w3.org/2001/XMLSchema-datatypes"


xsd_anyURI
 , xsd_QName
 , xsd_string
 , xsd_normalizedString
 , xsd_token
 , xsd_NMTOKEN
 , xsd_Name
 , xsd_NCName
 , xsd_ID
 , xsd_IDREF
 , xsd_ENTITY :: String

xsd_anyURI		= "anyURI"
xsd_QName		= "QName"
xsd_string		= "string"
xsd_normalizedString	= "normalizedString"
xsd_token		= "token"
xsd_NMTOKEN		= "NMTOKEN"
xsd_Name		= "Name"
xsd_NCName		= "NCName"
xsd_ID			= "ID"
xsd_IDREF		= "IDREF"
xsd_ENTITY		= "ENTITY"

xsd_length
 , xsd_maxLength
 , xsd_minLength
 , xsd_pattern
 , xsd_enumeration :: String

xsd_length	= rng_length
xsd_maxLength	= rng_maxLength
xsd_minLength	= rng_minLength
xsd_pattern	= "pattern"
xsd_enumeration	= "enumeration"


-- | The main entry point to the W3C XML schema datatype library.
--
-- The 'DTC' constructor exports the list of supported datatypes and params.
-- It also exports the specialized functions to validate a XML instance value with
-- respect to a datatype.
w3cDatatypeLib :: DatatypeLibrary
w3cDatatypeLib = (w3cNS, DTC datatypeAllowsW3C datatypeEqualW3C w3cDatatypes)


-- | All supported datatypes of the library
w3cDatatypes :: AllowedDatatypes
w3cDatatypes = [ (xsd_anyURI,		stringParams)
               , (xsd_QName,		stringParams)
               , (xsd_string,		stringParams)
	       , (xsd_normalizedString, stringParams)
               , (xsd_token,		stringParams)
               , (xsd_NMTOKEN,		stringParams)
	       , (xsd_Name,		stringParams)
	       , (xsd_NCName,		stringParams)
	       , (xsd_ID,		stringParams)
	       , (xsd_IDREF,		stringParams)
	       , (xsd_ENTITY,		stringParams)
               ]

-- | List of allowed params for the string datatypes
stringParams :: AllowedParams
stringParams = map fst $ fctTableString ++ fctTablePattern

-- | Function table for string tests,
-- XML document value is first operand, schema value second

fctTablePattern :: FunctionTable
fctTablePattern
    = [ (xsd_pattern,	patParamValid) ]

patParamValid :: String -> String -> Bool
patParamValid a regex
    = case parseRegex regex of
      (Left _  )	-> False
      (Right ex)	-> isNothing . match ex $ a


-- | Tests whether a XML instance value matches a data-pattern.
-- (see also: 'stringValid')

datatypeAllowsW3C :: DatatypeAllows
datatypeAllowsW3C d params value _
    | d == xsd_string
	= validString id value

    | d == xsd_normalizedString
	= validString normalizeBlanks value

    | d == xsd_token
	= validString normalizeBlanks value

    | d == xsd_NMTOKEN
	= check isNmtoken
	  `andCheck`
	  validString normalizeBlanks $ value

    | d == xsd_Name
	= check isName
	  `andCheck`
	  validString normalizeBlanks $ value

    | d `elem` [ xsd_NCName
	       , xsd_ID
	       , xsd_IDREF
	       , xsd_ENTITY
	       ]
        = check isNCName
	  `andCheck`
	  validString normalizeBlanks $ value

    | d == xsd_anyURI
	= check isURIReference
	  `andCheck`
	  validString escapeURI $ value

    | d == xsd_QName
	=  check isWellformedQualifiedName
	  `andCheck`
	  validString normalizeBlanks $ value

    | otherwise
	= alwaysErr notAllowed' value

    where
    check p = p `orErr` notValid

    validString normFct
	= validPattern
	  `andCheck`
	  ( validLength `withVal` normFct )
        where
	validLength  = stringValidFT fctTableString  d 0 (-1) (filter ((/= xsd_pattern) . fst) params)
	validPattern = stringValidFT fctTablePattern d 0 (-1) (filter ((== xsd_pattern) . fst) params)

    notValid v'      = errorMsgDataLibQName v' d w3cNS
    notAllowed' v'   = errorMsgDataTypeNotAllowed d params v' w3cNS

-- | Tests whether a XML instance value matches a value-pattern.

datatypeEqualW3C :: DatatypeEqual
datatypeEqualW3C d s1 _ s2 _
    | isJust nf
	= check (fromJust nf)
    | otherwise
	= Just $ errorMsgDataTypeNotAllowed0 d w3cNS
    where
    check f
	| s1' == s2' = Nothing
	| otherwise  = Just $ errorMsgEqual d s1' s2'
	where
	s1' = f s1
	s2' = f s2
    nf = lookup d norm
    norm = [ (xsd_string,		id			)
	   , (xsd_normalizedString,	normalizeBlanks		)
	   , (xsd_token,		normalizeWhitespace	)
	   , (xsd_NMTOKEN,		normalizeWhitespace	)
	   , (xsd_Name,			normalizeWhitespace	)
	   , (xsd_NCName,		normalizeWhitespace	)
	   , (xsd_ID,			normalizeWhitespace	)
	   , (xsd_IDREF,		normalizeWhitespace	)
	   , (xsd_ENTITY,		normalizeWhitespace	)
	   , (xsd_anyURI,		escapeURI . normalizeWhitespace	)
	   , (xsd_QName,		normalizeWhitespace	)
	   ]

-- ----------------------------------------
