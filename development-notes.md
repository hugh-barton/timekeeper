Issue: Goal completion state was recalculated in multiple places with separate implementations, which let the retroactive day editor drift from the primary logging flow.

Resolution: Moved goal completion recalculation to the shared habit progress logic and updated the direct logger, linked reward logger, and retroactive day editor to use the same helper.

Rule going forward: When multiple UI flows mutate habit progress, keep completion and progress reconciliation in shared logic rather than duplicating it inside individual views.

Issue: Reward progress calculations normalized start dates to the start of the day, which prevented same-day reactivation from truly resetting progress to zero.

Resolution: Updated reward progress calculations to respect the stored reward start timestamp for quantity and manual stamp entries, and reactivation now moves the reward start date forward instead of mutating linked habit history.

Rule going forward: When reset behavior depends on "from now" semantics, preserve timestamp precision in progress filters instead of collapsing everything to day boundaries.
