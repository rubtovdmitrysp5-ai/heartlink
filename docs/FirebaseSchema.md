# Firebase Schema

## users

```text
users/{userId}
  displayName: string
  email: string
  avatarURL: string?
  currentMood: happy | sad | missYou | busy
  partnerId: string?
  createdAt: timestamp
  updatedAt: timestamp?
```

## couples

```text
couples/{coupleId}
  firstUserId: string
  secondUserId: string
  startedAt: timestamp
  anniversaryDay: number
  anniversaryMonth: number
  inviteCode: string
  privateModeEnabled: bool
```

## messages

```text
couples/{coupleId}/messages/{messageId}
  authorId: string
  text: string
  kind: text | image | voice
  mediaURL: string?
  voiceDuration: number?
  reactions: array
  sentAt: timestamp
  isRead: bool
```

## memories

```text
couples/{coupleId}/memories/{memoryId}
  title: string
  note: string
  imageURL: string?
  locationName: string
  latitude: number?
  longitude: number?
  date: timestamp
  createdBy: string
```

## goals

```text
couples/{coupleId}/goals/{goalId}
  title: string
  detail: string
  kind: task | savings | wishlist
  progress: number
  targetAmount: number?
  currentAmount: number?
  dueDate: timestamp?
  isCompleted: bool
```

