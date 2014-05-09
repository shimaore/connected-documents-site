Db: `_auth`
===========

Type: `user`
------------

As per CouchDB spec, with additions:

    user_uuid   User's UUID, used e.g. to build user database name.

    created: true iff initial account creation is successful (userdb exists, etc.)
    validated: true iff email address has been validated

Db: 'public'
============

Only contains web content, no data.

Accessible publicly without authentication.

Db: 'shared'
============

Accessible to registered users.

Security:

    members.roles = ["user"]

Type: `store`
-------------

    _id: `store`
    name: string
    welcome_text: { language: string }

Attachments:

    logo.png

Type: `public_profile`
--------------------

A user's public profile.

    type: `public_profile`
    _id: `public_profile:` + user_uuid
    name: string, the user's pseudonym

Attachments:

    picture.jpeg: if present, the user's picture/icon

Type: `content`
---------------

Some publishable or published content. (Content might be purchased or made available for free.)
In the 'shared' database, only metadata of paid-for content is available.

    type: 'content'
    _id: `content:` + uuid
    content: uuid

    title:
    author:
    url:

    submitted_by: uuid of the user who submitted the content; null if store-provided

    _attachment.thumbnail

    (price, ..)

Attachments:

    cover.jpeg -- cover page or screenshot (for URLs)

    index.html etc. only for _free_ content.

Type: 'question'
----------------

Questions; the answers are stored in the private DB.

    type: 'question'
    _id: 'question:' + uuid
    question: uuid

    language:
    text:
    answer_type: either 'boolean', 'string' (free form), or an array of possible answers
    keep_anonymous:

Db: "user-#{user_uuid}"
=======================

Type: `store`
-------------

    _id: 'store'

    name: string
    subtitle:

Attachments: the offline version of the store.

    logo.png
    index.html etc.

Type: `profile`
---------------

    _id: 'profile'
    name: string (pseudonym)
    language: string (the user's preferred / current language)
    description: string
    publish.profile: false
    publish.description: false
    publish.picture: false

Attachments:

    picture.jpeg

Type: `public_profile`
----------------------

The local copy of the (shared) `public_profile`, if any.

Type: `content`
---------------

Replicated from `shared` or `private` databases with additional fields:

    categories: [] of category/bookshelves
    current_position: TBD reading position in the document

Attachments:

    index.html the main document describing the content
    etc.

Type: `answer`
--------------

    _id: 'answer:' + question_uuid
    question: question's id
    content: boolean, string, number,.. based on the answer_type field
    submitted: boolean

When submitted, is copied over into the `private` database.

Db: 'private'
==============================

Only accessible to internal (administrative/support) users.

Security:

    members.roles = ["internal_user"]

Type: 'answer'
--------------

    _id: 'answer:' + question_uuid + ':' + user_uuid
    question: question's uuid

Type: 'content'
---------------

Paid-for content. Same as `content` in `shared`, but contains attachments for paid-for content.
