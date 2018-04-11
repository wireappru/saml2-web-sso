{-# LANGUAGE StrictData          #-}
{-# LANGUAGE TemplateHaskell     #-}

module SAML.WebSSO.Types where

import Data.List.NonEmpty
import Data.String.Conversions (ST)
import Data.Time (UTCTime(..), formatTime, defaultTimeLocale)
import Lens.Micro.TH
import URI.ByteString


----------------------------------------------------------------------
-- meta

-- | [4/2.3.2]
data EntityDescriptor = EntityDescriptor
  { _edEntityID      :: ST
  , _edID            :: Maybe ID
  , _edValidUntil    :: Maybe Time
  , _edCacheDuration :: Maybe Duration
  , _edExtensions    :: [EntityDescriptionExtension]
  , _edRoles         :: [Role]
  }
  deriving (Eq, Show)

data EntityDescriptionExtension =
    EntityDescriptionDigestMethod URI
  | EntityDescriptionSigningMethod URI
  deriving (Eq, Show)

data Role =
    RoleRoleDescriptor RoleDescriptor
  | RoleIDPSSODescriptor IDPSSODescriptor
  | RoleSPSSODescriptor SPSSODescriptor
  deriving (Eq, Show)


-- | [4/2.4.1]
data RoleDescriptor = RoleDescriptor
  { _rssoID                         :: Maybe ID
  , _rssoValidUntil                 :: Maybe Time
  , _rssoCacheDuration              :: Maybe Duration
  , _rssoProtocolSupportEnumeration :: NonEmpty ST
  , _rssoErrorURL                   :: Maybe URI
  , _rssoKeyDescriptors             :: [KeyDescriptor]
  }
  deriving (Eq, Show)

-- | [4/2.4.1.1]
data KeyDescriptor = KeyDescriptor
  { _kdUse               :: Maybe KeyDescriptorUse
  , _kdKeyInfo           :: ()  -- TODO: xml:dsig key
  , _kdEncryptionMethods :: ()  -- TODO: xenc method
  }
  deriving (Eq, Show)

data KeyDescriptorUse = KeyDescriptorEncryption | KeyDescriptorSigning
  deriving (Eq, Show, Enum, Bounded)


-- | [4/2.4.4]
data SPSSODescriptor = SPSSODescriptor
  deriving (Eq, Show)


-- | [4/2.4.3]
data IDPSSODescriptor = IDPSSODescriptor
  { _idpWantAuthnRequestsSigned  :: Bool
  , _idpSingleSignOnService      :: NonEmpty EndPointNoRespLoc
  , _idNameIDMappingService      :: [EndPointNoRespLoc]
  , _idAssertionIDRequestService :: [EndPointAllowRespLoc]
  , _idAttributeProfile          :: [URI]
  }
  deriving (Eq, Show)

-- | [4/2.2.2].  Both binding and location should be type 'URI', but that's not how MSAD reads the
-- standards.
data EndPoint rl = EndPoint
  { _epBinding          :: ST
  , _epLocation         :: URI
  , _epResponseLocation :: rl
  }
  deriving (Eq, Show)

type EndPointNoRespLoc = EndPoint ()
type EndPointAllowRespLoc = EndPoint (Maybe URI)


----------------------------------------------------------------------
-- request, response

-- | [1/3.2.1], [1/3.4], [1/3.4.1]
--
-- interpretations of individual providers:
-- - <https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-single-sign-on-protocol-reference>
data AuthnRequest = AuthnRequest
  { _rqID               :: ID
  , _rqVersion          :: Version
  , _rqIssueInstant     :: Time
  , _rqIssuer           :: URI
  , _rqDestination      :: Maybe URI
  }
  deriving (Eq, Show)

-- | [1/3.2.2.1]
data Comparison = Exact | Minimum | Maximum | Better
  deriving (Eq, Show)

data RequestedAuthnContext = RequestedAuthnContext
  { _rqacAuthnContexts :: [ST] -- ^ either classRef or declRef
  , _rqacComparison    :: Comparison
  } deriving (Eq, Show)

-- | [1/3.4.1.1]
data NameIdPolicy = NameIdPolicy
  { _nidFormat          :: Maybe ST
  , _nidSpNameQualifier :: Maybe ST
  , _nidAllowCreate     :: Maybe Bool
  } deriving (Eq, Show)

-- | [1/3.4]
type AuthnResponse = Response [Assertion]

-- | [1/3.2.2]
data Response payload = Response
  { _rspID           :: ID
  , _rspInRespTo     :: ID
  , _rspVersion      :: Version
  , _rspIssueInstant :: Time
  , _rspDestination  :: Maybe URI
  , _rspIssuer       :: Maybe URI
  , _rspStatus       :: Status
  , _rspAssertion    :: payload
  }
  deriving (Eq, Show)


----------------------------------------------------------------------
-- misc

-- | [1/1.3.3] (we mostly introduce this type to override the unparseable default 'Show' instance.)
newtype Time = Time UTCTime
  deriving (Eq)

timeFormat :: String
timeFormat = "%Y-%m-%dT%H:%M:%S%QZ"

instance Show Time where
  showsPrec _ (Time t) = showString . show $ formatTime defaultTimeLocale timeFormat t

data Duration = Duration  -- TODO: https://www.w3.org/TR/xmlschema-2/#duration
  deriving (Eq, Show)

-- | IDs must be globally unique between all communication parties and adversaries with a negligible
-- failure probability.  [1/1.3.4]
newtype ID = ID { renderID :: ST }
  deriving (Eq, Show)

-- | [1/2.2.1]
newtype BaseID = BaseID { renderBaseID :: ST }
  deriving (Eq, Show)

-- | [1/2.2.3]
newtype NameID = NameID { renderNameID :: ST }
  deriving (Eq, Show)

data Version = Version_2_0
  deriving (Eq, Show, Bounded, Enum)

-- | [1/3.2.2.1;3.2.2.2]
data Status =
    StatusSuccess
  | StatusRequestDenied  -- ^ [2/3.5.6]
  deriving (Eq, Show, Bounded, Enum)


----------------------------------------------------------------------
-- assertion

-- | What the IdP has to say to the SP about the 'Subject'.  In essence, an 'Assertion' is a
-- 'Subject' and a set of 'Statement's on that 'Subject'.
data Assertion
  = Assertion  -- ^ [1/2.3.3]
    { _assVersion       :: Version
    , _assID            :: ID
    , _assIssueInstant  :: Time
    , _assIssuer        :: URI
    , _assConditions    :: Conditions
    , _assContents      :: SubjectAndStatements
    }
  deriving (Eq, Show)

-- | Conditions that must hold for an 'Assertion' to be actually asserted by the IdP.  [1/2.5]
data Conditions
  = Conditions
    { _condNotBefore           :: Maybe Time
    , _condNotOnOrAfter        :: Maybe Time
    , _condOneTimeUse          :: Bool   -- ^ [1/2.5.1.5]
    }
  deriving (Eq, Show)

-- | [1/2.3.3]
data SubjectAndStatements
  = SubjectAndStatements Subject [Statement]
  | SubjectOnly Subject
  | StatementsOnly [Statement]
  deriving (Eq, Show)

-- | Information about the client and/or user attempting to authenticate / authorize against the SP.
-- [1/2.4]
data Subject = Subject
  { _subjectID            :: Maybe SubjectID
  , _subjectConfirmations :: [SubjectConfirmation]
  }
  deriving (Eq, Show)

-- | See 'Subject'.  [1/2.4]
data SubjectID
  = SubjectBaseID BaseID
  | SubjectNameID NameID
  deriving (Eq, Show)

-- | Information about the kind of proof of identity the 'Subject' provided to the IdP.  [1/2.4]
data SubjectConfirmation = SubjectConfirmation
  { _scMethod :: ST
  , _scID     :: Maybe SubjectID
  , _scData   :: [SubjectConfirmationData]
  }
  deriving (Eq, Show)

-- | See 'SubjectConfirmation'.  [1/2.4.1.2]
data SubjectConfirmationData = SubjectConfirmationData
  { _scdNotBefore    :: Maybe Time
  , _scdNotOnOrAfter :: Maybe Time
  , _scdRecipient    :: Maybe URI
  , _scdInResponseTo :: Maybe ID
  , _scdAddress      :: Maybe ST
  }
  deriving (Eq, Show)


-- | The core content of the 'Assertion'.  [1/2.7]
data Statement
  = AuthnStatement  -- ^ [1/2.7.2]
    { _astAuthnInstant        :: Time
    , _astSessionIndex        :: Maybe ST
    , _astSessionNotOnOrAfter :: Maybe Time
    , _astSubjectLocality     :: Maybe Locality
    }
  | AttributeStatement  -- ^ [1/2.7.3]
    { _attrstAttrs :: NonEmpty Attribute
    }
  deriving (Eq, Show)


-- | [1/2.7.2.1]
data Locality = Locality
  { _localityAddress :: Maybe ST
  , _localityDNSName :: Maybe ST
  }
  deriving (Eq, Show)


-- | [1/2.7.3.1]
data Attribute =
    Attribute
    { _stattrName         :: ST
    , _stattrNameFormat   :: Maybe ST
    , _stattrFriendlyName :: Maybe ST
    , _stattrValue        :: [AttributeValue]
    }
  deriving (Eq, Show)

-- ^ [1/2.7.3.1.1]
data AttributeValue =
    AttributeValueInt Int
  | AttributeValueText ST
  deriving (Eq, Show)


----------------------------------------------------------------------
-- helper functions

-- | pull statements from different assertions of same shape into the same assertion.
-- [1/2.3.3]
normalizeAssertion :: [Assertion] -> [Assertion]
normalizeAssertion = error "normalizeAssertion: not implemented"


----------------------------------------------------------------------
-- record field lenses

makeLenses ''Assertion
makeLenses ''Attribute
makeLenses ''AttributeValue
makeLenses ''AuthnRequest
makeLenses ''BaseID
makeLenses ''Comparison
makeLenses ''Conditions
makeLenses ''Duration
makeLenses ''EndPoint
makeLenses ''EntityDescriptionExtension
makeLenses ''EntityDescriptor
makeLenses ''ID
makeLenses ''IDPSSODescriptor
makeLenses ''KeyDescriptor
makeLenses ''KeyDescriptorUse
makeLenses ''Locality
makeLenses ''NameID
makeLenses ''NameIdPolicy
makeLenses ''RequestedAuthnContext
makeLenses ''Response
makeLenses ''Role
makeLenses ''RoleDescriptor
makeLenses ''SPSSODescriptor
makeLenses ''Statement
makeLenses ''Status
makeLenses ''Subject
makeLenses ''SubjectAndStatements
makeLenses ''SubjectConfirmation
makeLenses ''SubjectConfirmationData
makeLenses ''SubjectID
makeLenses ''Time
makeLenses ''Version
