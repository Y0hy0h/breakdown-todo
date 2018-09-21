module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Css exposing (..)
import Css.Global exposing (global, selector)
import Html.Styled exposing (Attribute, Html, button, div, form, input, label, li, main_, ol, section, span, text, toUnstyled)
import Html.Styled.Attributes exposing (autofocus, css, id, type_, value)
import Html.Styled.Events exposing (on, onClick, onInput, onSubmit, stopPropagationOn)
import Json.Decode as Decode
import List.Extra as List
import Tasks
import Url


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequest
        , onUrlChange = \_ -> NoOp
        }



-- MODEL


type Current
    = Current


type Done
    = Done


type alias Model =
    { key : Nav.Key
    , newTask : String
    , currentTasks : Tasks.Collection Current
    , doneTasks : Tasks.Collection Done
    , editing : Maybe Int
    }


init flags url key =
    simply
        { key = key
        , newTask = ""
        , currentTasks = Tasks.empty Current
        , doneTasks = Tasks.empty Done
        , editing = Nothing
        }


simply : Model -> ( Model, Cmd Msg )
simply model =
    ( model, Cmd.none )



-- UPDATE


type Msg
    = NoOp
    | UrlRequest Browser.UrlRequest
    | UpdateNewTask String
    | AddNewTask
    | DoTask (Tasks.TaskId Current)
    | UndoTask (Tasks.TaskId Done)
    | StartEdit Int
    | Edit (Tasks.TaskId Current) String
    | CloseEdit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            simply model

        UrlRequest request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UpdateNewTask action ->
            simply { model | newTask = action }

        AddNewTask ->
            let
                newTasks =
                    addTask model.newTask model.currentTasks
            in
            simply
                { model
                    | currentTasks = newTasks
                    , newTask = ""
                }

        DoTask id ->
            let
                ( newCurrentTasks, newDoneTasks ) =
                    Tasks.moveTask id model.currentTasks model.doneTasks
            in
            simply
                { model
                    | currentTasks = newCurrentTasks
                    , doneTasks = newDoneTasks
                    , editing = Nothing
                }

        UndoTask id ->
            let
                ( newDoneTasks, newCurrentTasks ) =
                    Tasks.moveTask id model.doneTasks model.currentTasks
            in
            simply
                { model
                    | doneTasks = newDoneTasks
                    , currentTasks = newCurrentTasks
                }

        StartEdit index ->
            simply { model | editing = Just index }

        CloseEdit ->
            simply { model | editing = Nothing }

        Edit id newRawAction ->
            let
                newCurrentTasks =
                    case Tasks.actionFromString newRawAction of
                        Just action ->
                            Tasks.editTask id action model.currentTasks

                        Nothing ->
                            model.currentTasks
            in
            simply { model | currentTasks = newCurrentTasks }


addTask : String -> Tasks.Collection c -> Tasks.Collection c
addTask rawAction currentTasks =
    case Tasks.actionFromString rawAction of
        Just action ->
            Tasks.addTask action currentTasks

        Nothing ->
            currentTasks



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Breakdown"
    , body =
        List.map toUnstyled
            [ global
                [ selector "body"
                    [ displayFlex
                    , justifyContent center
                    , margin (em 1)
                    , fontFamily sansSerif
                    ]
                ]
            , main_
                [ css
                    [ minWidth (em 20) ]
                ]
                [ viewActionInput model.newTask
                , let
                    renderTask =
                        case model.editing of
                            Nothing ->
                                \index task -> viewTask index False task

                            Just editIndex ->
                                \index task -> viewTask index (editIndex == index) task
                  in
                  viewTaskList [ marginTop (em 1.5) ] <| List.indexedMap renderTask <| Tasks.toList model.currentTasks
                , viewTaskList [ marginTop (em 1.5) ] <| List.indexedMap viewDoneTasks <| Tasks.toList model.doneTasks
                ]
            ]
    }


viewActionInput : String -> Html Msg
viewActionInput currentAction =
    form [ onSubmit AddNewTask, css [ flex (num 1) ] ]
        [ label []
            [ span [ css [ hide ] ] [ text "New task's action" ]
            , input
                [ type_ "text"
                , value currentAction
                , onInput UpdateNewTask
                , autofocus True
                , css [ boxSizing borderBox, width (pct 100) ]
                ]
                []
            ]
        , div
            [ css
                [ displayFlex
                , flexDirection row
                , justifyContent center
                ]
            ]
            [ label []
                [ span [ css [ hide ] ] [ text "Add new task" ]
                , input [ css [ buttonStyle ], type_ "submit", value "➕" ] []
                ]
            , label []
                [ span [ css [ hide ] ] [ text "Clear input" ]
                , input [ css [ buttonStyle ], type_ "reset", value "❌", onClick (UpdateNewTask "") ] []
                ]
            ]
        ]


viewTaskList : List Style -> List (Html Msg) -> Html Msg
viewTaskList styles =
    ol [ css ([ listStyleType none, margin zero, padding zero, maxWidth (em 20) ] ++ styles) ]
        << List.map
            (\task ->
                li
                    [ css
                        [ hover [ backgroundColor (rgba 0 0 0 0.03) ]
                        , pseudoClass "not(:last-child)"
                            [ borderBottom3 (px 1) solid (rgba 0 0 0 0.1)
                            ]
                        ]
                    ]
                    [ task ]
            )


viewTask : Int -> Bool -> Tasks.Task Current -> Html Msg
viewTask index isEditing task =
    viewTaskBase
        index
        (if isEditing then
            onClick CloseEdit

         else
            onClick (StartEdit index)
        )
        (if isEditing then
            viewEditAction (Tasks.getId task) (Tasks.readAction task)

         else
            viewAction [] <| Tasks.readAction task
        )
        (iconButton (DoTask <| Tasks.getId task) "Mark as done" "✔️")


idForTask : Int -> String
idForTask index =
    "task-" ++ String.fromInt index


viewDoneTasks : Int -> Tasks.Task Done -> Html Msg
viewDoneTasks index task =
    viewTaskBase
        index
        (onClick NoOp)
        (viewAction
            [ textDecoration lineThrough
            , opacity (num 0.6)
            ]
         <|
            Tasks.readAction task
        )
        (iconButton (UndoTask <| Tasks.getId task) "Mark as to do" "🔄")


viewTaskBase : Int -> Attribute Msg -> Html Msg -> Html Msg -> Html Msg
viewTaskBase index whenClicked action btn =
    div
        [ id (idForTask index)
        , css
            [ displayFlex
            , alignItems center
            , justifyContent spaceBetween
            , padding (em 0.5)
            ]
        , whenClicked
        ]
        [ action
        , btn
        ]


viewAction : List Style -> String -> Html Msg
viewAction textStyles action =
    span
        [ css
            ([ whiteSpace noWrap
             , overflow hidden
             , textOverflow ellipsis
             , flex (num 1)
             ]
                ++ textStyles
            )
        ]
        [ text action ]


viewEditAction : Tasks.TaskId Current -> String -> Html Msg
viewEditAction id currentAction =
    form
        [ onSubmit CloseEdit
        ]
        [ label []
            [ span [ css [ hide ] ] [ text "Action" ]
            , input
                [ type_ "text"
                , value currentAction
                , onInput (Edit id)
                , stopPropagation
                , css [ boxSizing borderBox, width (pct 100) ]
                ]
                []
            ]
        , div
            []
            [ label []
                [ span [ css [ hide ] ] [ text "Undo changes" ]
                , input [ css [ buttonStyle ], onButtonClick CloseEdit, type_ "reset", value "️↩️" ] []
                ]
            ]
        ]


stopPropagation : Attribute Msg
stopPropagation =
    stopPropagationOn "click" (Decode.succeed ( NoOp, True ))


iconButton : Msg -> String -> String -> Html Msg
iconButton msg hint icon =
    button [ onButtonClick msg, css [ buttonStyle ] ] [ span [ css [ hide ] ] [ text hint ], text icon ]


onButtonClick : Msg -> Attribute Msg
onButtonClick msg =
    stopPropagationOn "click" (Decode.succeed ( msg, True ))


{-| Only fires for clicks exactly on the element.

See <https://javascript.info/bubbling-and-capturing#event-target> for further information.

-}
onClickWithId : String -> Msg -> Attribute Msg
onClickWithId targetId msg =
    on "click"
        (Decode.at [ "target", "id" ] Decode.string
            |> Decode.andThen
                (\actualId ->
                    if actualId == targetId then
                        Decode.succeed msg

                    else
                        Decode.fail <| "Element id was " ++ actualId ++ ", expected " ++ targetId ++ "."
                )
        )


buttonStyle : Style
buttonStyle =
    let
        size =
            em 2
    in
    batch
        [ border zero
        , padding zero
        , width size
        , height size
        , textAlign center
        , backgroundColor (rgba 0 0 0 0.1)
        , hover [ backgroundColor (rgba 0 0 0 0.07) ]
        , active [ boxShadow5 inset (em 0.1) (em 0.1) (em 0.2) (rgba 0 0 0 0.1) ]
        , margin (em 0.1)
        ]


{-| Hides an element visually, but keeps it discoverable to assistive technologies.

See <https://www.w3.org/WAI/tutorials/forms/labels/#note-on-hiding-elements> for further information.

-}
hide : Style
hide =
    batch
        [ border zero
        , property "clip" "rect(0 0 0 0)"
        , height (px 1)
        , margin (px -1)
        , overflow hidden
        , padding zero
        , position absolute
        , whiteSpace noWrap
        , width (px 1)
        ]
