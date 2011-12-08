/**
 * Copyright Université Lyon 1 / Université Lyon 2 (2011)
 *
 * <ithaca@liris.cnrs.fr>
 *
 * This file is part of Visu.
 *
 * This software is a computer program whose purpose is to provide an
 * enriched videoconference application.
 *
 * Visu is a free software subjected to a double license.
 * You can redistribute it and/or modify since you respect the terms of either
 * (at least one of the both license) :
 * - the GNU Lesser General Public License as published by the Free Software Foundation;
 *   either version 3 of the License, or any later version.
 * - the CeCILL-C as published by CeCILL; either version 2 of the License, or any later version.
 *
 * -- GNU LGPL license
 *
 * Visu is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Visu is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Visu.  If not, see <http://www.gnu.org/licenses/>.
 *
 * -- CeCILL-C license
 *
 * This software is governed by the CeCILL-C license under French law and
 * abiding by the rules of distribution of free software.  You can  use,
 * modify and/ or redistribute the software under the terms of the CeCILL-C
 * license as circulated by CEA, CNRS and INRIA at the following URL
 * "http://www.cecill.info".
 *
 * As a counterpart to the access to the source code and  rights to copy,
 * modify and redistribute granted by the license, users are provided only
 * with a limited warranty  and the software's author,  the holder of the
 * economic rights,  and the successive licensors  have only  limited
 * liability.
 *
 * In this respect, the user's attention is drawn to the risks associated
 * with loading,  using,  modifying and/or developing or reproducing the
 * software by the user in light of its specific status of free software,
 * that may mean  that it is complicated to manipulate,  and  that  also
 * therefore means  that it is reserved for developers  and  experienced
 * professionals having in-depth computer knowledge. Users are therefore
 * encouraged to load and test the software's suitability as regards their
 * requirements in conditions enabling the security of their systems and/or
 * data to be ensured and,  more generally, to use and operate it in the
 * same conditions as regards security.
 *
 * The fact that you are presently reading this means that you have had
 * knowledge of the CeCILL-C license and that you accept its terms.
 *
 * -- End of licenses
 */
package com.ithaca.traces
{
/* For remoting */

import flash.events.EventDispatcher;

import mx.collections.ArrayCollection;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.rpc.remoting.RemoteObject;

/**
 * Usage:
 * the TraceManager class is a singleton, which
 * provides static methods. Usage is:
 *
 * - at application start, initialize the trace with an alias, and the uid and possibly the URI:
 *   trace = TraceManager.initTrace('main', uid=loggedUser.id, uri='http:...');
 *   or use
 *   TraceManager.registerTrace('main', t);
 *   to register an existing Trace.
 *
 * - to log an Obsel:
 *   import com.ithaca.traces.TraceManager;
 *   TraceManager.trace("main", "PresenceStart", { email: loggedUser.mail, surname: loggedUser.firstname, name: loggedUser.lastName });
 *
 */
[Bindable]
public class TraceManager
{
    /**
     * Singleton instance of the TraceManager
     */
    private static var instance: TraceManager = null;

    /**
     * alias->Trace mapping
     */
    public var traces: Object;

    private static var logger: ILogger = Log.getLogger("com.ithaca.traces.TraceManager");

    /**
     * Constructor
     */
    public function TraceManager()
    {
        traces = new Object();
    }

    /**
     * Register an existing trace in the TraceManager.
     * If a different trace with the same alias exists, raise an exception.
     * Else, return the trace.
     */
    public static function registerTrace(alias: String, tr: Trace): Trace
    {
        if (getInstance().traces.hasOwnProperty(alias))
        {
            if (getTrace(alias) !== tr) 
            {
                // Cannot overwrite an already existing class
                throw new Error(alias + " is already registered for another class");
            }
        } else {
            getInstance().traces[alias] = tr;
        }
        return tr;
    }

    /**
     * Initialise a new Trace for the given alias and return it.
     *
     * This is basically a shortcut for registerTrace(alias, new Trace());
     * If a trace already exists for the alias, then we return the existing Trace.
     */
    public static function initTrace(alias: String, uid: int = 0, uri: String = ""): Trace
    {
        var tr: Trace;

        if (getInstance().traces.hasOwnProperty(alias))
        {
            tr = getTrace(alias);
        }
        else
        {
            logger.debug("initTrace: creating new trace: " + alias);
            // Not yet existing. Create a new one
            tr = new Trace(uid, uri);
            getInstance().traces[alias] = tr;
        }
        return tr;
    }

    /**
     *
     */
    public static function getTrace(alias: String): Trace
    {
        return getInstance().traces[alias] as Trace;
    }

    /**
     * Returns the Singleton instance of the TraceManager
     */
    public static function getInstance() : TraceManager
    {
        if (instance == null)
        {
            logger.debug("Creating new TraceManager instance");
            instance = new TraceManager();
        }
        return instance;
    }

    /**
     * Convenience static method to quickly create an Obsel and
     * add it to the specified trace.
     */
    public static function trace(alias: String, type: String, props: Object = null, begin: Number = 0, end: Number = 0): Obsel
    {
        var o: Obsel;
        var t: Trace;

        t = getTrace(alias);

        // FIXME: what to do if t === undefined ?

        try
        {
            o = t.trace(type, props, begin, end);
        }
        catch (error:Error)
        {
            logger.debug("Exception in trace: " + error);
        }
        return o;
    }

}

}
