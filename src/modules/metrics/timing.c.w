/* This file is part of P^nMPI.
 *
 * Copyright (c)
 *  2008-2017 Lawrence Livermore National Laboratories, United States of America
 *  2011-2017 ZIH, Technische Universitaet Dresden, Federal Republic of Germany
 *  2013-2017 RWTH Aachen University, Federal Republic of Germany
 *
 *
 * P^nMPI is free software; you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation version 2.1 dated February 1999.
 *
 * P^nMPI is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with P^nMPI; if not, write to the
 *
 *   Free Software Foundation, Inc.
 *   51 Franklin St, Fifth Floor
 *   Boston, MA 02110, USA
 *
 *
 * Written by Martin Schulz, schulzm@llnl.gov.
 *
 * LLNL-CODE-402774
 */

#include <stdio.h>

#include <hires-timers.h>
#include <mpi.h>
#include <pnmpi/debug_io.h>
#include <pnmpi/hooks.h>
#include <pnmpi/private/pmpi_assert.h>
#include <pnmpi/private/tls.h>
#include <pnmpi/service.h>
#include <pnmpi/xmpi.h>

#include "atomic.h"


/* If there is no atomic support or no thread local storage support, we'll limit
 * the threading level of this module to MPI_THREAD_SERIALIZED, so it is safe to
 * use with threaded applications (but they may become slower!). */
#if defined(METRIC_NO_ATOMIC) || defined(PNMPI_COMPILER_NO_TLS)
const int PNMPI_SupportedThreadingLevel = MPI_THREAD_SERIALIZED;
#endif


/** \brief Struct of timing storage.
 *
 * \details This struct stores the time spent for each MPI calls.
 */
static struct timing_storage
{
  {{forallfn fn_name}}
  metric_atomic_keyword timing_t {{fn_name}};
  {{endforallfn}}
} timing_storage;


/** \brief Global variable to store how often this module was invoked.
 */
metric_atomic_keyword size_t metric_invocations = metric_atomic_init(0);


/** \brief Global variable to store how often this module was invoked with
 *   Pcontrol enabled.
 */
metric_atomic_keyword size_t metric_invocations_pcontrol =
  metric_atomic_init(0);


/** \brief Helper function to print \ref timing_storage struct.
 *
 * \details This function will print all functions called at least one
 *  nanosecond.
 *
 *
 * \param t \ref timing_storage struct to be printed.
 */
static void print_counters(struct timing_storage *t)
{
  {{forallfn fn_name}}
  if (t->{{fn_name}} > 0)
    printf("  %13.9fs %s\n", t->{{fn_name}} * 0.000000001, "{{fn_name}}");
  {{endforallfn}}
}


/** \brief Helper function to initialize counter struct.
 *
 * \details This function will set all counters in \p counter to zero.
 *
 *
 * \param t \ref timing_struct to be initialized.
 */
static void init_counters(struct timing_storage *t)
{
  {{forallfn fn_name}}
  t->{{fn_name}} = metric_atomic_init(0);
  {{endforallfn}}
}


/** \brief PnMPI module initialization hook.
 *
 * \details This function sets all counters to zero and initializes the module.
 */
void PNMPI_Init()
{
  init_counters(&timing_storage);

  /* The timing statics should be printed after all MPI_Finalize calls of the
   * following PnMPI levels and stacks have been finished. As the timers may be
   * invoked at different levels to track only some of the PnMPI levels, we have
   * to count how often this module is in the PnMPI stack to know how many
   * MPI_Finalize calls we have to ignore. */
  metric_atomic_inc(metric_invocations);


  /* Timing for MPI_Pcontrol is available for metric-timing invocations before
   * and after the modules to test only. To satisfy this, we'll check for each
   * invocation of this module, if it's Pcontrol-enabled. If it is, a counter
   * will be increased. It will be checked when calling MPI_Pcontrol. */
  if (PNMPI_Service_GetPcontrolSelf())
    metric_atomic_inc(metric_invocations_pcontrol);
}


/** \brief Helper function to start and end \p timer.
 *
 *
 * \param timer The timer to be started / stoped.
 *
 * \return 0 The timer was started.
 * \return >0 The timer was stoped and the elapsed time will be returned.
 */
static timing_t start_stop_timer(timing_t *t)
{
  if (*t != 0)
    {
      timing_t tmp = get_time_ns() - *t;
      *t = 0;
      return tmp;
    }

  *t = get_time_ns();
  return 0;
}


/* Generate wrapper functions for all MPI calls to start and stop the counters
 * on every call. MPI_Finalize will be ignored, because it will be used to print
 * the statistics below. */

{{fnall fn_name MPI_Finalize MPI_Pcontrol}}
  /* The local timer will be defined as thread local storage, as each thread may
   * call the function to be measured at the same time. With thread local
   * storage, each thread has its own timer and does not get into conflict with
   * other threads.
   *
   * This variable also will be used to indicate, if the timer is active. If the
   * timer is 0, it is inactive, otherise it is active. */
  static pnmpi_compiler_tls_keyword timing_t timer = 0;


  metric_atomic_add(timing_storage.{{fn_name}}, start_stop_timer(&timer));
  WRAP_MPI_CALL_PREFIX
  int ret = X{{fn_name}}({{args}});
  WRAP_MPI_CALL_POSTFIX
  metric_atomic_add(timing_storage.{{fn_name}}, start_stop_timer(&timer));

  return ret;
{{endfnall}}


/* MPI_Pcontrol needs special handling, as it doesn't call a PMPI function and
 * PnMPI does not implement the required XMPI call. Instead PnMPI will act as a
 * multiplexer for MPI_Pcontrol, so all we have to do is increment the counter
 * and return.
 *
 * The second problem is, we can't measure the timings in simple mode, as we
 * need a start- and end-point to measure the time, but PnMPI gives us (per
 * default) only the start-point. To overcome this metric_invocations_pcontrol
 * must be devideable by two, so the first call is our start- and the second the
 * end-time.
 *
 * Note: This option requires both modules set pcontrol to 'on'! */

int MPI_Pcontrol(const int level, ...)
{
  /* At this point it is save to get metric_invocations without any atomic
   * safety, as writes only occur in PnMPI_Registration_Point. */
  if ((metric_invocations_pcontrol % 2) != 0)
    PNMPI_Error("metric-timing can measure the time of MPI_Pcontrol in "
                "advanced mode, only.\n");


  /* The local timer will be defined as thread local storage, as each thread may
   * call the function to be measured at the same time. With thread local
   * storage, each thread has its own timer and does not get into conflict with
   * other threads.
   *
   * This variable also will be used to indicate, if the timer is active. If the
   * timer is 0, it is inactive, otherise it is active. */
  static pnmpi_compiler_tls_keyword timing_t timer = 0;
  metric_atomic_add(timing_storage.MPI_Pcontrol, start_stop_timer(&timer));

  return MPI_SUCCESS;
}


/** \brief Print the statistics.
 *
 * \details This function will print the statistics to stdout for each rank and
 *  a sum of all ranks.
 *
 *
 * \return The return value of PMPI_Finalize will be pass through.
 */
int MPI_Finalize()
{
  /* The local timer will be defined as thread local storage, as each thread may
   * call the function to be measured at the same time. With thread local
   * storage, each thread has its own timer and does not get into conflict with
   * other threads.
   *
   * This variable also will be used to indicate, if the timer is active. If the
   * timer is 0, it is inactive, otherise it is active. */
  static pnmpi_compiler_tls_keyword timing_t timer = 0;

  metric_atomic_add(timing_storage.MPI_Finalize, start_stop_timer(&timer));
  int ret = XMPI_Finalize();
  metric_atomic_add(timing_storage.MPI_Finalize, start_stop_timer(&timer));


  /* Only the first module in the PnMPI stack should print the timing statistics
   * AFTER all the other stacks have finished. As this module may have been
   * invoked more than once in the stack, we've counted how often it was invoked
   * in the registration point. We'll decrease this counter for each invocation
   * of MPI_Finalize. If the counter is zero, we know that this is the first
   * call to this module in the PnMPI stack. */
  size_t level = metric_atomic_dec(metric_invocations);
  if (level != 0)
    return ret;


  /* Wait until all ranks have flushed their buffers to avoid rank output
   * between the statistics output. */
  fflush(stdout);
  fflush(stderr);
  PMPI_Barrier_assert(MPI_COMM_WORLD);


  int rank, size;

  PMPI_Comm_rank_assert(MPI_COMM_WORLD, &rank);
  PMPI_Comm_size_assert(MPI_COMM_WORLD, &size);


  /* First we iterate over all ranks to print the per-rank statistics. We'll do
   * this ordered by rank.
   *
   * This solution was inspired by: http://stackoverflow.com/a/5310506 */
  int n = 0;
  while (n < size)
    {
      if (rank == n)
        {
          if (rank == 0)
            printf("\n\nTiming stats:\n");

          printf("Rank %d:\n", rank);
          print_counters(&timing_storage);
          fflush(stdout);
        }
      n++;

      PMPI_Barrier_assert(MPI_COMM_WORLD);
    }


  /* Reduce statistics of all ranks to rank 0 to print the summed up timings for
   * all ranks. */
  struct timing_storage tmp;
  init_counters(&tmp);

  {{forallfn fn_name}}
  PMPI_Reduce_assert(&(timing_storage.{{fn_name}}), &(tmp.{{fn_name}}), 1,
                     MPI_UNSIGNED_LONG_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
  {{endforallfn}}

  if (rank == 0)
    {
      printf("Total:\n");
      print_counters(&tmp);
      fflush(stdout);
    }


  return ret;
}
