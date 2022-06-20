---
title: "Project Management 101 for Software Engineers"
subtitle: "Tips on being a better Tech Lead"
date: 2020-06-27T17:37:16-07:00
draft: true
---

So you're leading a software development project for the first time, or you're interested in improving your current project management framework? Below are just of few of my recommended things to focus on.

### Don't Skip The Up-Front Work

Grooming is the (oft-undervalued) job of making sure work items (Jira tickets) are _actionable_. When requirements are vague or incomplete, engineers are either paralyzed or hampered: if they aren't blocked by unusuable requirements, they will produce features that are either incorrect or incomplete.

It's the job of product managers and engineering leaders to _groom_ tickets before getting estimates from the team. This is a classic garbage-in garbage-out scenario: poor tickets produce poor estimates and poor results.


### Plan to Change the Plan

"Agile" is so-called for a reason. It's meant to adapt easily to changing requirements and moving goalposts. The team should be confident in their sprint estimations, and be excited to meet their sprint goals; but unexpected roadblocks and SNAFUs come up at the least opportune times, and adaptability can make or break a project.

When bugs are discovered, they should undergo a standardized process of impact-estimation (how bad is this?) and prioritization (how quickly do we need to resolve it?). If they are deemed important and urgent enough to amend the current sprint, there needs to be another standardized process for descoping some feature work to make room for bug resolution. This change should be communicated not only to your team, but to any external stakeholders as well.

A team that can quickly adapt and communicate a plan of action will build an image of poise and strength (see the below sections on communication). But a team that flails at every new bug will quickly lose the respect of the organization, and will be seen as the bottleneck -- instead of the engine of productivity.

### Map the Work onto the Organization

**Conway's Law**, coined by the renowned Fred Brooks and named after the equaly esteemed Mel Conway, is an axiom regarding the structure of teams:

> Any organization that designs a system (defined broadly) will produce a design whose structure is a copy of the organization's communication structure. [1](https://www.melconway.com/Home/Conways_Law.html)

The same way that software packages A and B cannot properly integrate without their respective author's communication, so too does a development team need work-items to be organized in a way that reflect the team. But, "what does that mean?", you're probably asking.

It means Sprints, and Epics, and User Stories are all well and good, but if the Jira tickets don't match the way the team works, the Jira board will become a dreaded chore instead of a tool.

An epic may reflect a unit of business value, i.e. a set of features that produce some workflow for the end user. But a single engineer likely won't find it useful to think in terms of epics: they may take weeks or months to complete (many sprints), and may be put on hold, abandoned, etc. More commonly, user stories are often the unit of work for an engineer. They pick up a story during the sprint, move it to "In Progress", and later move it to "Done" once they have finished (usually before the end of the sprint). This sounds like a great system, and it is, when the "stories" are appropriate in scope.

The "story writers" need to take into account the shape of the team. Is it a cross-functional team, with front-end, back-end and QA developers? Then a user story may be subdivided into tasks that can be accomplished by each individually, linked with "blocking" relationships if a specific order of operations is necessary (for instance, QA validation comes last, but maybe the QA specification is written first!). A user story that holds all the information for all 3 developers is going to be massive, probably confusing, and likely to get out of sync with changing requirements. The actionable work items need to be small enough that a single engineeer can be solely responsible for it's completion, but no so small that engineers become bogged down moving tickets. There is a balance to be achieved.

Get feedback on what is working and what isn't (hold regular retrospectives!). Observe the lifecycle of tickets, are user stories "In Progress" for much longer than they should be? Make small tweaks to the team's "ticket protocol"; the scrum master, product managers and engineering leaders should be responsible for ensuring adherence to that protocol, and shouldering menial housekeeping tasks if they exist, with the goal of eliminating them entirely.


### Ensure Clear Communication Channels and Protocols

How are bugs documented and disseminated? How are new features requested and prioritized? How are questions on requirements or specifications shared?

These are questions whose answers must be known by all team members at all times. 

Small teams likely get away with putting everything in Slack: communication can move fast and everyone can stay up-to-date on everything. But Slack breaks down as a team grows. It's a medium meant for quick questions and quick answers, but it makes it hard to document decisions and find past information. Things get buried.

Perhaps your team wiki (i.e. Confluence) can serve as the source-of-truth for your team? If the team decides Product Requirements Documents are "living" documents, then the team needs to make sure they are kept up-to-date. Maybe the Trello board is all the documentation you need? Or perhaps there is a specific Slack channel for each project, and decisions are starred on the channel (not my recommended method, but whatever works for you).

What's important in all those examples is adhering a protocol in order to **manage expectations**. Managers, engineers and stakeholders need to know where they can **expect** to find information at all times. If team members don't know where to find an answer to their question, the question will be repeatedly asked and repeatedly answered, and the answers might slowly change over time -- I call this "decision slippage". If a team experiences decisions slippage, team members will *think* they are on the same page, but in reality everyone will have a *different understanding* of what they are building -- and that never ends well.

The protocols for communicating these things need to be simple and clear. Email has long served as the information highway of organizations, because it's permanent, structured and searchable:

- Permanent: historic emails cannot change
- Structured: subjects === topic, recipients === team/stakeholders and message === decision
- Searchable: Find the original decision, and follow the thread of replies to see how it changes over time

Email can be viewed as a commit log of decision making. Where wikis like Confluence change over time and hide much of that history, email *necessitates* that changes be explained as they occur (i.e. "Per Jorge's last question, we are changing Requirement 7 to require 30% integration").

The point is, use what works best for your team, and don't be afraid to speak up if the current communication patterns aren't working. In the time of COVID-19, remote work takes some adapting to, and your team will only get better by actively trying to improve.

### Overcommunicate "up"

Overcommunicating. It may sound negative, like you're "annoying" the listener or drowning them in information. That might be the case if you overcommunicate face-to-face! But overcommunication, when combined with the proper channels and protocols (see the above section), is the best possible way to manage expecations and gain the respect of the organization.

Like I mentioned in the section on "Changing Plans", communicating change helps everyone. But it's important to communicate *before* changes happen, as well.

At the beginning of a sprint, at the end of a sprint, maybe even at the halfway point of a sprint: communicate "up" to the stakeholders outside your team. Engineering leadership, sales and marketing are examples of "upward and outward" stakeholders. If they are kept in the loop, they will be more invested in the engineers' success, and in turn will be more open to communicate their needs and desires, and present you with opportunities to make the entire organization more effective and productive.


### Overcommunicate "down"

Overcommunicating should be pursued internally within the team as well. 

Make sure the entire team is made aware of bug discoveries and production incidents. Be transparent about the process of feature prioritization, especially when they change the current sprint. Communicate not only the "what" but the "why": software engineering is "knowledge work", your team members are building a system from scratch, they need to be invested in its success and the worst thing you can do is give them the impression that their work is futile in the face of requirements that constantly change without reason. 

"Thrash" is dangerous for any organization, software development teams not excluded. If things are changing, your team needs to know why. If they are told the motivations of the organization-at-large, they can better predict the needs of the company and build a better product in turn. If they are kept in the dark, they will continue to build features from the confines of an information-silo; technical debt will mount, and productivity will suffer.

### Set Your Targets

All of these tips have one goal in mind: **accomplish more**. Being an effective engineering leader is much more than grooming and communication, but I feel this post covers the salient points for organizing an effective software project. 

What projects are you leading right now? What is working, and what isn't working? What changes have you tried, and what improvements have you seen? What questions do you have about effective project management? We'd love to hear from you, with comments or questions. And I am always glad to take requests for future posts.

Until next time - 
