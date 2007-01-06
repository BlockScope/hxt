-- |
-- HTML Parser
--
-- Version : $Id: HtmlParser.hs,v 1.4 2006/11/12 14:53:00 hxml Exp $
--
-- This parser tries to interprete everything as HTML
-- no errors are emitted during parsing. If something looks
-- weired, warning messages are inserted in the document tree
--
-- module contains state filter for easy parsing and error handling
-- real work is done in 'Text.XML.HXT.Parser.HtmlParsec'

module Text.XML.HXT.Parser.HtmlParser
    ( getHtmlDoc
    , parseHtmlDoc
    , runHtmlParser
    , module Text.XML.HXT.Parser.HtmlParsec
    )

where

import Text.XML.HXT.DOM.XmlTree
import Text.XML.HXT.DOM.XmlState
import Text.XML.HXT.Parser.HtmlParsec

import Text.XML.HXT.Parser.XmlInput
    ( getXmlContents
    )

import Text.XML.HXT.Parser.XmlOutput
    ( traceTree
    , traceSource
    , traceMsg
    )

-- ------------------------------------------------------------

-- |
-- read a document and parse it with 'parseHtmlDoc'. The main entry point of this module
--
-- The input tree must be a root tree like in '	Text.XML.HXT.Parser.MainFunctions.getXmlDoc'. The content is read with 'Text.XML.HXT.Parser.XmlInput.getXmlContents',
-- is parsed with 'parseHtmlDoc' and canonicalized (char refs are substituted in content and attributes,
-- but comment is preserved)
--
-- see also : 'Text.XML.HXT.Parser.DTDProcessing.getWellformedDoc'

getHtmlDoc	:: XmlStateFilter state
getHtmlDoc
    = setSystemParams
      .>>
      getXmlContents
      .>>
      parseHtmlDoc

-- | The HTML parsing filter
--
-- The input is parsed with 'runHtmlParser', everything is interpreted as HTML,
-- if errors ocuur, the parser will try to do some meaningfull action and continues
-- parsing. Afterwards the entitiy references for defined for XHTML are resovled,
-- any unresolved reference is transformed into plain text.
--
-- Error messages
-- during parsing and entity resolving are added as warning nodes into the resulting tree.
--
-- The warnings are issued, if the 1. parameter noWarnings is set to True,
-- afterwards all are removed from the resulting tree.

parseHtmlDoc	:: XmlStateFilter a
parseHtmlDoc
    = parseDoc
      `whenM` ( isRoot .> getChildren .> isXText )
      where
      parseDoc t'
	  = ( traceMsg 2 ("parseHtmlDoc: parse HTML document " ++ show loc)
	      .>>
	      runHtmlParser
	      .>>
	      liftMf (processTopDown substHtmlEntities)
	      .>>
	      removeWarnings
	      .>>
	      traceTree
	      .>>
	      traceSource
              ) $ t'
	  where
	  loc    = valueOf a_source t'			-- get document source uri

      removeWarnings	:: XmlStateFilter a
      removeWarnings t'
	  = let
	    noWarnings  = not (satisfies (hasOption a_issue_warnings) t')
	    selWarnings = deep
			  ( choice [ isWarning :-> this
				   , isXTag    :-> (getAttrl .> selWarnings)
				   ]
			  )
	    remWarnings = processTopDown
			  ( choice [ isWarning :-> none
				   , isXTag    :-> (processAttrl (remWarnings $$))
				   , this      :-> this
				   ]
			  )
	    warnings = selWarnings t'
	    in do 
	       if null warnings
		  then thisM t'
		  else do
		       if noWarnings
			  then return []
			  else do
			       issueError $$< warnings
		       return (remWarnings t')

-- | The pure HTML parser, usually called via 'parseHtmlDoc'.
--

runHtmlParser	:: XmlStateFilter a
runHtmlParser t
    = if null errs
      then do
	   return (replaceChildren res t)
      else do
	   issueError $$< errs
	   return (setStatus c_err "parsing HTML" t)
      where
      res  = getChildren .> parseHtmlText loc $ t
      errs = isXError .> neg isWarning $$ res
      loc  = valueOf a_source t


-- ------------------------------------------------------------