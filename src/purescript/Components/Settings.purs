module Components.Settings where

import Control.Applicative ((<$>))
import Control.Bind (discard)
import Control.Category (identity)
import Control.Monad (class Monad)
import Control.Monad.State.Class (class MonadState)
import Control.Semigroupoid ((<<<))
import Data.Boolean (otherwise)
import Data.Const (Const)
import Data.Either (Either(..))
import Data.Function (($), (#), const)
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.Ord ((<), (>))
import Data.Semigroup ((<>))
import Data.Show (show)
import Data.Unit (Unit, unit)
import Data.Void (Void)
import Effect.Aff (Milliseconds(..))
import Effect.Aff.Class (class MonadAff)
import Effect.Class.Console (logShow)
import Effect.Console (log)

import Halogen.Component (ComponentSlot)
import Halogen.HTML as HTML
import Halogen.HTML.Events as HTML.Events
import Halogen.HTML.Properties as HTML.Properties

import Formless as Formless
import Formless.Types.Component (Slot')
import Halogen as Halogen

import Components.Utils.UIChunks as UIChunks
import Components.Utils.Validation as Validation
import Components.Utils.Validation (FieldError(..))


type    Surface     = HTML.HTML
data    Action      = HandleForm State
                    | Click
data    Query a     = GetSettings (Settings -> a)
type    Input       = Settings
data    Output      = UpdatedSettings Settings
                    | RegeneratePassword
type    State       = Settings
type    Slot        = Halogen.Slot Query Output

type    ChildSlots  = ()

type Slots = (
    formless :: Slot' Form Settings Unit
)


data    CharacterSet = CapitalLetters | LowercaseLetters | Digits | Space | Symbols
type    Settings = {
    length :: Int
--  characterSets :: Set CharacterSet,
--  characters :: String
}

-- ###########################################################################################

type FormData f = (
    -- name    :: f Validation.FieldError   String  String,
    -- email   :: f Validation.FieldError   String  Validation.Email,
    length :: f Validation.FieldError String Int
)

newtype Form r f = Form (r (FormData f))
derive instance newtypeForm :: Newtype (Form r f) _

formInput :: forall m. Monad m => Formless.Input' Form m
formInput = {
    initialInputs: Nothing,
    validators: Form {
        length: Formless.hoistFnE_ \str -> case Int.fromString str of
            Nothing -> Left (InvalidInt str)
            Just n
                | n < 0  -> Left (TooShort n)
                | n > 30 -> Left (TooLong n)
                | otherwise -> Right n
    }
}

type    FormQuery = (Const Void)
type    FormInput = Unit

formComponent :: forall m. MonadAff m => Formless.Component Form FormQuery ChildSlots FormInput State m
formComponent = Formless.component (const formInput) $ Formless.defaultSpec {
        render          = renderForm,               --  const (HTML.text mempty)    :: PublicState form state   ->  ComponentHTML form action slots m
    --  handleAction    = const (pure unit)         --                              :: action                   ->  HalogenM form state action slots msg m Unit
    --  handleQuery     = const (pure Nothing)      --                              :: forall a. query a        ->  HalogenM form state action slots msg m (Maybe a)
        handleEvent     = Formless.raiseResult      --  const(pure unit)            :: Event form st            ->  HalogenM form state action slots msg m Unit
    --  receive         = const Nothing,            --                              :: input                    ->  Maybe action
    --  initialize      = Nothing,                  --                              ::                              Maybe action
    --  finalize        = Nothing                   --                              ::                              Maybe action
    }
    where
        renderForm { form } = UIChunks.formContent_ [
            UIChunks.input {
                label: "Password Length",
                help: Formless.getResult formData.length form # UIChunks.resultToHelp "How long do you want your password to be?",
                placeholder: "32"
            } [
                HTML.Properties.value $ Formless.getInput formData.length form,
                HTML.Events.onValueInput $ Just <<< Formless.asyncSetValidate (Milliseconds 500.0) formData.length
            ],
            UIChunks.buttonPrimary
                [ HTML.Events.onClick \_ -> Just Formless.submit ]
                [ HTML.text "Submit" ]
        ]
            where
            formData = Formless.mkSProxies (Formless.FormProxy :: _ Form)

-- formComponent' :: forall m. MonadAff m => Formless.Component Form FormQuery ChildSlots FormInput State m
-- formComponent' = Formless.component (const formInput) $ Formless.defaultSpec {
--     handleEvent = Formless.raiseResult,
--     render      = formRender'
-- }

-- formRender' { form } = 
--     let
--         formData = Formless.mkSProxies (Formless.FormProxy :: _ Form)
--     in
--         UIChunks.formContent_ [
--             UIChunks.input {
--                 label: "Password Length",
--                 help: Formless.getResult formData.length form # UIChunks.resultToHelp "How long do you want your password to be?",
--                 placeholder: "32"
--             } [
--                 HTML.Properties.value $ Formless.getInput formData.length form,
--                 HTML.Events.onValueInput $ Just <<< Formless.asyncSetValidate (Milliseconds 500.0) formData.length
--             ],

--             UIChunks.buttonPrimary
--                 [ HTML.Events.onClick \_ -> Just Formless.submit ]
--                 [ HTML.text "Submit" ]
--         ]

-- ###########################################################################################

-- mkComponent :: ∀ surface state query action slots input output m. ComponentSpec surface state query action slots input output m → Component surface query input output m
-- mkComponent :: ∀ surface state query action slots input output m. { eval ∷ forall a. HalogenQ query action input a -> HalogenM state action slots output m a , initialState ∷ input -> state , render ∷ state -> surface (ComponentSlot surface slots m action) action } → Component surface query input output m

component :: forall m. MonadAff m => Halogen.Component Surface Query Input Output m
component = Halogen.mkComponent {
    initialState:   initialState,   -- :: Input -> State
    render:         render,         -- :: State -> Surface (ComponentSlot Surface Slots m Action) Action
    eval: Halogen.mkEval $ Halogen.defaultEval {
        handleAction = handleAction,    --  handleAction    :: forall m. MonadAff m => Action → Halogen.HalogenM State Action Slots Output m Unit
        handleQuery  = handleQuery,     --  handleQuery     :: forall m a. Query a -> Halogen.HalogenM State Action Slots Output m (Maybe a)
        receive      = receive,         --  receive         :: Input -> Maybe Action
        initialize   = initialize,      --  initialize      :: Maybe Action
        finalize     = finalize         --  finalize        :: Maybe Action
    }
}

initialState :: Input -> State
initialState = identity

render :: forall m. MonadAff m => State -> Surface (ComponentSlot Surface Slots m Action ) Action
render ({length:length}) = HTML.div [HTML.Properties.class_ (Halogen.ClassName "settings")] [
    HTML.h1  [] [HTML.text (show length)],
    HTML.slot Formless._formless unit formComponent unit (Just <<< HandleForm),
    HTML.button [HTML.Properties.title "new", HTML.Events.onClick \_ -> Just Click] [HTML.text "new"]
]

handleAction :: forall m. MonadAff m => Action -> Halogen.HalogenM State Action Slots Output m Unit
handleAction = case _ of
    Click -> do
        Halogen.liftEffect $ log "Settings: click \"new\""
        Halogen.raise RegeneratePassword
    HandleForm s -> do
        Halogen.liftEffect $ log "HandleForm: " <> logShow (s :: State)


handleQuery :: forall m a. MonadState State m => Query a -> m (Maybe a)
handleQuery = case _ of
    GetSettings k -> do
        --result::Settings <- Halogen.get
        --pure (Just (k result))
        Just <<< k <$> Halogen.get

receive :: Input -> Maybe Action
receive = const Nothing

initialize :: Maybe Action
initialize = Nothing

finalize :: Maybe Action
finalize = Nothing

