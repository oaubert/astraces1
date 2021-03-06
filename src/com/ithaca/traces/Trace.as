/**
 * Copyright Université Lyon 1 / Université Lyon 2 (2009,2010,2011)
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

import flash.utils.Timer;
import flash.events.EventDispatcher;
import flash.events.TimerEvent;

import mx.collections.ArrayCollection;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.rpc.remoting.RemoteObject;
import com.ithaca.traces.events.TraceEvent;

// From as3corelibs
import com.adobe.serialization.json.JSON;

/**
 * Usage:
 * - at application start, initialize the trace with the uid and possibly the URI:
 *   myTrace = new Trace(uri='http:...', uid=loggedUser.id);
 * - to log an Obsel:
 *   myTrace.trace("PresenceStart", { email: loggedUser.mail, surname: loggedUser.firstname, name: loggedUser.lastName });
 */
[Bindable]
public class Trace extends EventDispatcher
{
    /**
     * Shared RemoteObject
     */
    public static var traceRemoteObject: RemoteObject;

    private var logger:ILogger = Log.getLogger("com.ithaca.traces.Trace");

    public var uri: String = "";
    public var uid: int = 0;

    public var obsels: ArrayCollection;

    public var fusionedObselTypes: Object = new Object();
    private var fusionBuffer: Vector.<Obsel> = new Vector.<Obsel>();
    public var lastObsel: Obsel = null;

    /* If True, automatically synchronize with the KTBS */
    public var autosync: Boolean = true;

    /* Timer used for non-blocking loading of obsels */
    private var loadingTimer: Timer = null;
    /* store information for loading: data array, index, etc.
       The appropriate method would be to create a custom timer event,
       but this will do for an interim code */
    private var loadingInfo: Object = null;

    /* Number of items to parse during a parsing iteration. Note that
    it is not the number of Obsels, since @prefix lines are considered
    as elements. */
    public var PARSING_BATCH_SIZE: int = 100;

    /* Timeout (in ms) for the Timer doing batch parsing */
    public var PARSING_TIMEOUT: int = 150;

    public function twoDigits(n: int): String
    {
        if (n < 10)
            return "0" + n.toString();
        else
            return n.toString();
    }

    public function Trace(uid: int = 0, uri: String = ""): void
    {
        var d: Date = new Date();
        // FIXME: debug for the moment (since KTBS is not used):
        if (uri == "")
            uri = "trace-" + d.fullYear + twoDigits(d.month + 1) + twoDigits(d.date) + twoDigits(d.hours) + twoDigits(d.minutes) + twoDigits(d.seconds) + "-" + uid;
        this.uri = uri;
        this.uid = uid;
        this.obsels = new ArrayCollection()
    }

    /**
     * Update the given trace from a TTL serialization.
     *
     * If reset is true, then first remove all existing obsels from
     * the trace.
     *
     * The loading is non-blocking: the method will return immediately.
     *
     * The trace object will dispatch PARSING_PROGRESS events with
     * value (float, 0< <1) and message (String) attributes, so that a
     * progress bar can be displayed.
     *
     * When the trace is fully loaded, the trace will dispatch a
     * PARSING_DONE event.
     */
    public function updateFromRDF(ttl: String, reset: Boolean = true): Boolean
    {
        var e: TraceEvent;
        var oldAutosync: Boolean = this.autosync;

        if (loadingTimer !== null)
            return false;

        this.autosync = false;

        if (reset)
            this.obsels.removeAll();

        e = new TraceEvent(TraceEvent.PARSING_PROGRESS);
        e.value = 0;
        e.message = "Splitting data";
        this.dispatchEvent(e);

        //we split the ttl on each "." line (kind of an "end of instruction" in ttl (?))
        var ar: Array = ttl.split(/\.\s*$/m);

        loadingInfo = new Object();
        loadingInfo.data = ar;
        loadingInfo.index = 0;
        loadingInfo.parser = partialParseTTL;
        loadingInfo.oldAutosync = oldAutosync;

        loadingTimer = new Timer(PARSING_TIMEOUT);
        loadingTimer.addEventListener(TimerEvent.TIMER, loadingTimerCallback);
        loadingTimer.start();
        return true;
    }

    /**
     * Update the given trace from a Json serialization.
     *
     * If reset is true, then first remove all existing obsels from
     * the trace.
     *
     * The loading is non-blocking: the method will return immediately.
     *
     * The trace object will dispatch PARSING_PROGRESS events with
     * value (float, 0< <1) and message (String) attributes, so that a
     * progress bar can be displayed.
     *
     * When the trace is fully loaded, the trace will dispatch a
     * PARSING_DONE event.
     */
    public function updateFromJSON(json: String, reset: Boolean = true): Boolean
    {
        var e: TraceEvent;
        var oldAutosync: Boolean = this.autosync;

        if (loadingTimer !== null)
            return false;

        this.autosync = false;

        if (reset)
            this.obsels.removeAll();

        e = new TraceEvent(TraceEvent.PARSING_PROGRESS);
        e.value = 0;
        e.message = "Splitting data";
        this.dispatchEvent(e);

        var data: Object = JSON.decode(json);
        var ar: Array = data['obsels'];

        loadingInfo = new Object();
        loadingInfo.data = ar;
        loadingInfo.index = 0;
        loadingInfo.parser = partialParseJSON;
        loadingInfo.oldAutosync = oldAutosync;

        loadingTimer = new Timer(PARSING_TIMEOUT);
        loadingTimer.addEventListener(TimerEvent.TIMER, loadingTimerCallback);
        loadingTimer.start();
        return true;
    }

    private function loadingTimerCallback(event: TimerEvent): void
    {
        var e: TraceEvent;

        if (loadingInfo === null)
        {
            /* Strange problem, it should not be null. Cancelling the
             * timer. */
            loadingTimer.stop();
            loadingTimer.removeEventListener(TimerEvent.TIMER, loadingTimerCallback);
            loadingTimer = null;
            return;
        }
        /* Parse a chunk of data */
        loadingInfo.index = loadingInfo.parser(loadingInfo.data, loadingInfo.index);

        /* Dispatch progress event */
        e = new TraceEvent(TraceEvent.PARSING_PROGRESS);
        e.value = loadingInfo.index / loadingInfo.data.length;
        e.message = "Parsed " + this.obsels.length + " obsels";
        this.dispatchEvent(e);

        /* Check for process end */
        if (loadingInfo.index >= loadingInfo.data.length)
        {
            loadingTimer.stop();
            loadingTimer.removeEventListener(TimerEvent.TIMER, loadingTimerCallback);
            loadingTimer = null;

            this.autosync = loadingInfo.oldAutosync;
            loadingInfo = null;

            e = new TraceEvent(TraceEvent.PARSING_DONE);
            e.value = 1.0;
            e.message = "Parsed " + this.obsels.length + " obsels";
            this.dispatchEvent(e);
        }
    }

    /*
     * Parse PARSING_BATCH_SIZE obsels from a TTL array
     *
     * Return the index of the next item to parse.
     */
    private function partialParseTTL(data: Array, index: int): int
    {
        var i: int = 0;
        var l: String;
        for (i = index; i < index + PARSING_BATCH_SIZE; i++)
        {
            if (i >= data.length)
            {
                return i;
            }
            l = data[i];
            // Ignore prefixes for the moment. We should parse them
            if (l.substr(0, 7) == '@prefix')
                continue;
            // Append the trailing . again to get a valid TTL serialization.
            l = l + "\n.\n";

            var obs: Obsel = new Obsel("temp");
            obs.updateFromRDF(l);

            //if the initialization from the ttl chunk is ok, we add the obsel to the trace
            if (obs.type != "temp")
            {
                this.addObsel(obs);
            }
        }
        return i;
    }

    /*
     * Parse PARSING_BATCH_SIZE obsels from a JSON array
     *
     * Return the index of the next item to parse.
     */
    private function partialParseJSON(data: Array, index: int): int
    {
        var i: int = 0;
        var l: String;
        for (i = index; i < index + PARSING_BATCH_SIZE; i++)
        {
            if (i >= data.length)
            {
                return i;
            }
            var obs: Obsel = new Obsel("temp");
            obs.updateFromJSON(data[i]);

            //if the initialization from the json chunk is ok, we add the obsel to the trace
            if (obs.type != "temp")
            {
                this.addObsel(obs);
            }
        }
        return i;
    }

    public function get remote(): RemoteObject
    {
        return traceRemoteObject;
    }

    public static function init_remote(server: String): void
    {
        // Initialise RemoteObject
        traceRemoteObject = new RemoteObject();
        traceRemoteObject.endpoint=server;
        traceRemoteObject.destination = "ObselService";
        traceRemoteObject.makeObjectsBindable=true;
        traceRemoteObject.showBusyCursor=false;
    }

    /**
     * Declare an obsel type that should be fusioned.
     *
     * For obsels that can be generated in sequential quantities (such
     * as the variation of the position of a slider), generating one
     * event for each position change is too heavy and generated many
     * obsels.
     *
     * We can declare this kind of type as
     * FusionedTypes. Trace.trace() will then bufferize obsels of
     * given type, until an obsel of a different type is sent. In this
     * case, the buffer obsels will be concatenated into a single
     * Fusioned<Type>, which will possess List<prop> attributes for
     * each <prop> property of the original obsels. The List<prop>
     * attributes will contain the list of successive values.
     */
    public function addFusionedType(typ: String): void
    {
        this.fusionedObselTypes[typ] = true;
    }

    public function addObsel(obsel: Obsel): Obsel
    {
        if (obsel.uid == 0)
            obsel.uid = this.uid;

        obsel.trace = this;

        this.obsels.addItem(obsel);

        if (this.autosync)
        {
            obsel.toSGBD();
        }
        return obsel;
    }
    public function delObsel(obsel :Obsel):void
    {
        obsel.trace = this;
        if(this.autosync)
        {
            obsel.deleteObselSGBD();
        }
    }
    public function updObsel(obsel:Obsel):void
    {
        obsel.trace = this;

        if(this.autosync)
        {
            obsel.updateObselSGBD();
        }
    }

    /**
     * Return the set of obsels matching type.
     */
    public function filter(type: String): ArrayCollection
    {
        var result: ArrayCollection = new ArrayCollection();

        for each (var obs: Obsel in this.obsels)
        {
            if (obs.type == type)
            {
                result.addItem(obs);
            }
        }
        return result;
    }

    override public function toString(): String
    {
        return "Trace with " + this.obsels.length + " element(s)";
    }

    /**
     * Flush fusion buffer
     *
     * Create a new Obsel by gathering data from fusionBuffer
     * contents. It begin is the begin time of the first obsel, its
     * end time is the begin time of the last obsel.
     */
    private function flushFusionBuffer(): void
    {
        var prop: String;
        var ref: Obsel;

        if (this.fusionBuffer.length == 0)
            return;

        ref = this.fusionBuffer[0];

        /* Use first obsel as reference */
        var o: Obsel = new Obsel("Fusioned" + ref.type,
                                 ref.uid,
                                 null,
                                 ref.begin,
                                 this.fusionBuffer[this.fusionBuffer.length - 1].begin);
        for (prop in ref.props)
        {
            o.props[prop + "List"] = new Array();
        }

        /* Fusion data */
        for each (var obs: Obsel in this.fusionBuffer)
        {
            for (prop in ref.props)
            {
                o.props[prop + "List"].push(obs.props[prop]);
            }
        }
        addObsel(o);
        /* Clear fusion buffer */
        /* 4294967295 : default value for splice(), from the doc:
           http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/Vector.html#splice%28%29 */
        fusionBuffer.splice(0, 4294967295);
    }

    /**
     * Flush possibly buffered data.
     */
    public function flush(): void
    {
        if (this.fusionBuffer.length != 0)
        {
            flushFusionBuffer();
        }
    }

    /**
     * Convenience method to quickly create an Obsel and
     * add it to the trace.
     */
    public function trace(type: String, props: Object = null, begin: Number = 0, end: Number = 0): Obsel
    {
        var o: Obsel;

        try
        {
            o = new Obsel(type, uid, props, begin, end);

            if (this.lastObsel != null && this.lastObsel.type != type)
                /* Flush buffer */
                this.flushFusionBuffer();

            if (fusionedObselTypes.hasOwnProperty(type))
                this.fusionBuffer.push(o)
            else
                /* Append new obsel */
                this.addObsel(o);

            this.lastObsel = o;
            //logger.debug("\n===\n" + o.toRDF() + "\n===\n");
        }
        catch (error:Error)
        {
            logger.debug("Exception in trace: " + error);
        }
        return o;
    }

    /**
     * Return a Tab-Separated-Values representation of the trace
     *
     * The table features one column per attribute.
     */

    public function toTSV(): String
    {
        var o: Obsel;
        var fields: Array = new Array();
        var type2col: Object = new Object();
        var row: Vector.<String> = new Vector.<String>();
        var data: Array = new Array();
        var p: String;

        fields.push("ktbs:begin");
        fields.push("ktbs:end");
        fields.push("ktbs:type");
        fields.push("ktbs:subject");
        for (var i: int = 0; i < fields.length ; i++)
            type2col[i] = i;

        /* Convert a Trace to Tab-Separated-Value format */
        for each (o in this.obsels)
        {
            row.splice(0, 4294967295);
            row.length = fields.length;

            row[0] = Obsel.value2repr(o.begin);
            row[1] = Obsel.value2repr(o.end);
            row[2] = Obsel.value2repr(o.type);
            row[3] = Obsel.value2repr(o.uid);
            for (p in o.props)
            {
                if (! type2col.hasOwnProperty(p))
                {
                    fields.push(p);
                    type2col[p] = fields.length - 1;
                }
                row[type2col[p]] = Obsel.value2repr(o.props[p], false, true)
            }
            for (i = 0; i < row.length; i++)
                if (row[i] === null)
                    row[i] = "";
            // Print row
            data.push(row.join("\t"));
        }
        data.unshift(fields.join("\t"));
        return data.join("\n");
    }

    /**
     * Return a TTL representation of the trace.
     */
    public function toTTL(): String
    {
        var data: Array = new Array();
        for each (var o: Obsel in this.obsels)
            data.push(o.toRDF());
        return data.join("\n\n");
    }
}

}
