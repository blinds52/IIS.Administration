// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.


namespace Microsoft.IIS.Administration.WebServer.RequestFiltering
{
    using Applications;
    using AspNetCore.Mvc;
    using Web.Administration;
    using System.Net;
    using Sites;
    using Core.Http;
    using Core;

    [RequireGlobalModule("RequestFilteringModule", "IIS Request Filtering")]
    public class RequestFilteringController : ApiBaseController
    {
        [HttpGet]
        [ResourceInfo(Name = Defines.RequestFilteringName)]
        public object Get()
        {
            Site site = ApplicationHelper.ResolveSite();
            string path = ApplicationHelper.ResolvePath();

            if (path == null) {
                return NotFound();
            }

            dynamic d = RequestFilteringHelper.ToJsonModel(site, path);
            return LocationChanged(RequestFilteringHelper.GetLocation(d.id), d);
        }

        [HttpGet]
        [ResourceInfo(Name = Defines.RequestFilteringName)]
        public object Get(string id)
        {
            RequestFilteringId reqId = new RequestFilteringId(id);

            Site site = reqId.SiteId == null ? null : SiteHelper.GetSite(reqId.SiteId.Value);

            if (reqId.SiteId != null && site == null) {
                Context.Response.StatusCode = (int)HttpStatusCode.NotFound;
                return null;
            }

            return RequestFilteringHelper.ToJsonModel(site, reqId.Path);
        }

        [HttpPatch]
        [Audit]
        [ResourceInfo(Name = Defines.RequestFilteringName)]
        public object Patch(string id, [FromBody] dynamic model)
        {
            RequestFilteringId reqId = new RequestFilteringId(id);

            Site site = reqId.SiteId == null ? null : SiteHelper.GetSite(reqId.SiteId.Value);

            if (reqId.SiteId != null && site == null) {
                Context.Response.StatusCode = (int)HttpStatusCode.NotFound;
                return null;
            }

            // Check for config_scope
            string configPath = model == null ? null : ManagementUnit.ResolveConfigScope(model);
            RequestFilteringSection section = RequestFilteringHelper.GetRequestFilteringSection(site, reqId.Path, configPath);

            RequestFilteringHelper.UpdateFeatureSettings(model, section);

            ManagementUnit.Current.Commit();

            return RequestFilteringHelper.ToJsonModel(site, reqId.Path);
        }

        [HttpDelete]
        [Audit]
        public void Delete(string id)
        {
            RequestFilteringId reqId = new RequestFilteringId(id);

            Context.Response.StatusCode = (int)HttpStatusCode.NoContent;

            Site site = (reqId.SiteId != null) ? SiteHelper.GetSite(reqId.SiteId.Value) : null;

            if (site == null) {
                return;
            }

            var section = RequestFilteringHelper.GetRequestFilteringSection(site, reqId.Path, ManagementUnit.ResolveConfigScope());

            section.RevertToParent();

            ManagementUnit.Current.Commit();
        }
    }
}
