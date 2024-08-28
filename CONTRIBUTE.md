Contribution Model
=============================

Teams are welcome to contribute to this codebase.
The following guidelines should be followed when making a contribution.

The Goal of having these guidelines in place is to: Maintain a high
level of code quality and maintainability while facilitating teams to
contribute to the code base.

**IMPORTANT NOTES**

-   Reviews will NOT be merged after Tuesday in the last week of the Sprint.
-   All reviews must contain 2 gerrit links, for both the EO and IDUN repos.

**Step 1: Identify the change and create a JIRA**

-   JIRA should be created on your own board
-   Send the JIRA to Honey Pots to see if the JIRA is valid before
    progressing to step 2.\
    Use Honey Pots Distribution List - PDLHONEYPO@pdl.internal.ericsson.com
-   Decision Taken at this point on whether Step 2 Design Analysis is required or whether it goes straight to development.

**Step 2: Design Analysis Proposal**

-   Complete a Design Analysis and populate the JIRA ticket with it.
-   Send the JIRA with the Design Analysis to the Honey Pots Team
-   Two members of Honey Pots team identified as key reviewers of
    the design analysis.\
    Honey Pots will review the design and give feedback on the JIRA in a
    similar format to that of a code review (-2,-1,+1,+2)
-   The goal is to respond within 24 hours. Reviewers may request that
    the assignee organise a meeting to discuss the design analysis
    further.
-   Once a +1 and +2 has been given you can proceed to step 3

**Step 3: After implementation and testing is complete Send for code review**

-   Review should follow the Honey Pots Code Review [Process](https://confluence-oss.seli.wh.rnd.internal.ericsson.com/display/ESO/HP+Code+Review),
[Guidelines](https://confluence-oss.seli.wh.rnd.internal.ericsson.com/display/ESO/HP+Code+Review+Guidelines)
and [Checklist](https://confluence-oss.seli.wh.rnd.internal.ericsson.com/display/ESO/HP+Code+Review+Checklist).
-   Reviews should be kept small (No more than 300 lines of code per
    review).
-   Reviews should be submitted independently(No parent code reviews).
-   Code must not break any pipelines or existing tests.
-   New functionality needs to include tests.

**Step 4: Code is merged**

-   The reviewer who gives the +2 will merge the code.
-   The reviewer will follow the commit through the pipeline.

**IMPORTANT NOTES**

-   Reviews will NOT be merged after Tuesday in the last week of the Sprint.
-   All reviews must contain 2 gerrit links, for both the EO and IDUN repos.
